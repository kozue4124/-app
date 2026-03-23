#!/bin/bash
# このファイルをダブルクリックするだけで起動します（Mac用）

cd "$(dirname "$0")"

# GitHubから最新のapp.pyをダウンロード（失敗時は内蔵コードを使用）
GITHUB_MAIN="https://raw.githubusercontent.com/kozue4124/-app/main/app.py"
GITHUB_BRANCH="https://raw.githubusercontent.com/kozue4124/-app/claude/auto-subtitle-generator-zbRhe/app.py"

if curl -sf --connect-timeout 10 "$GITHUB_MAIN" -o app.py 2>/dev/null; then
    echo "最新版のapp.pyをダウンロードしました (main)"
elif curl -sf --connect-timeout 10 "$GITHUB_BRANCH" -o app.py 2>/dev/null; then
    echo "最新版のapp.pyをダウンロードしました (branch)"
else
    echo "オフラインモード: 内蔵コードを使用します"
    cat > app.py << 'APPEOF'
"""
自動字幕生成システム - Whisperを使った音声・動画ファイルから字幕を生成するWebアプリ
"""

import os
import tempfile
import subprocess
from pathlib import Path

import whisper
import gradio as gr


# サポートするファイル形式
AUDIO_EXTENSIONS = [".mp3", ".wav", ".m4a", ".aac", ".flac", ".ogg", ".wma"]
VIDEO_EXTENSIONS = [".mp4", ".mov", ".avi", ".mkv", ".webm", ".wmv", ".flv"]
SUPPORTED_EXTENSIONS = AUDIO_EXTENSIONS + VIDEO_EXTENSIONS

# Whisperモデルの選択肢
MODEL_OPTIONS = {
    "tiny（最速・低精度）": "tiny",
    "base（速い・標準精度）": "base",
    "small（バランス良好）": "small",
    "medium（高精度）": "medium",
    "large（最高精度・低速）": "large",
}

# 言語の選択肢
LANGUAGE_OPTIONS = {
    "自動検出": None,
    "日本語": "ja",
    "英語": "en",
    "中国語": "zh",
    "韓国語": "ko",
    "フランス語": "fr",
    "ドイツ語": "de",
    "スペイン語": "es",
    "イタリア語": "it",
    "ポルトガル語": "pt",
    "ロシア語": "ru",
}


def extract_audio_from_video(video_path: str, output_path: str) -> str:
    """動画ファイルから音声を抽出する"""
    cmd = [
        "ffmpeg",
        "-i", video_path,
        "-vn",
        "-acodec", "pcm_s16le",
        "-ar", "16000",
        "-ac", "1",
        "-y",
        output_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"音声抽出に失敗しました: {result.stderr}")
    return output_path


def format_timestamp(seconds: float) -> str:
    """秒数をSRT形式のタイムスタンプに変換する"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds % 1) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


# 日本語の自然な改行位置を判断するための文字セット
_BREAK_PUNCT = set('。、！？…')
_BREAK_PARTICLES = set('はがをにでともへやかねよわ')


def find_natural_break(text: str, max_pos: int) -> int:
    """max_pos文字以内で最も自然な改行位置を返す"""
    limit = min(max_pos, len(text))
    # 句読点の後を優先
    for pos in range(limit, max(limit // 2, 1), -1):
        if text[pos - 1] in _BREAK_PUNCT:
            return pos
    # 助詞の後
    for pos in range(limit, max(limit // 2, 1), -1):
        if text[pos - 1] in _BREAK_PARTICLES:
            return pos
    return limit


def split_text_to_pages(text: str, max_chars: int = 15, max_lines: int = 2) -> list:
    """テキストを字幕ページ（最大max_lines行×max_chars文字）のリストに分割する"""
    pages = []
    remaining = text.strip()

    while remaining:
        lines = []
        for _ in range(max_lines):
            if not remaining:
                break
            if len(remaining) <= max_chars:
                lines.append(remaining)
                remaining = ""
                break
            pos = find_natural_break(remaining, max_chars)
            lines.append(remaining[:pos])
            remaining = remaining[pos:]
        if lines:
            pages.append("\n".join(lines))

    return pages if pages else [text.strip()]


def expand_segment(segment: dict, max_chars: int = 15, max_lines: int = 2) -> list:
    """セグメントを字幕エントリのリストに展開する（無音・空テキストはスキップ）"""
    text = segment["text"].strip()
    if not text or segment.get("no_speech_prob", 0) > 0.6:
        return []

    pages = split_text_to_pages(text, max_chars, max_lines)

    if len(pages) == 1:
        return [{"start": segment["start"], "end": segment["end"], "text": pages[0]}]

    # 複数ページに分割する場合は時間を均等割り
    duration = segment["end"] - segment["start"]
    page_duration = duration / len(pages)
    entries = []
    for i, page_text in enumerate(pages):
        entries.append({
            "start": segment["start"] + i * page_duration,
            "end": segment["start"] + (i + 1) * page_duration,
            "text": page_text,
        })
    return entries


def segments_to_srt(segments: list) -> str:
    """Whisperのセグメントデータをsrt形式に変換する"""
    srt_lines = []
    counter = 1
    for segment in segments:
        for entry in expand_segment(segment):
            start = format_timestamp(entry["start"])
            end = format_timestamp(entry["end"])
            srt_lines.append(f"{counter}\n{start} --> {end}\n{entry['text']}\n")
            counter += 1
    return "\n".join(srt_lines)


def segments_to_vtt(segments: list) -> str:
    """Whisperのセグメントデータをvtt形式に変換する"""
    vtt_lines = ["WEBVTT\n"]
    counter = 1
    for segment in segments:
        for entry in expand_segment(segment):
            start = format_timestamp(entry["start"]).replace(",", ".")
            end = format_timestamp(entry["end"]).replace(",", ".")
            vtt_lines.append(f"{counter}\n{start} --> {end}\n{entry['text']}\n")
            counter += 1
    return "\n".join(vtt_lines)


def segments_to_txt(segments: list) -> str:
    """Whisperのセグメントデータをプレーンテキストに変換する"""
    lines = []
    for segment in segments:
        text = segment["text"].strip()
        if not text:
            continue
        start = format_timestamp(segment["start"])
        end = format_timestamp(segment["end"])
        lines.append(f"[{start} --> {end}] {text}")
    return "\n".join(lines)


def generate_subtitles(
    file_obj,
    model_name: str,
    language: str,
    output_format: str,
    progress=gr.Progress(),
):
    if file_obj is None:
        return "", None, "ファイルをアップロードしてください。"

    file_path = file_obj if isinstance(file_obj, str) else file_obj.name
    file_ext = Path(file_path).suffix.lower()

    if file_ext not in SUPPORTED_EXTENSIONS:
        return "", None, f"非対応のファイル形式です。対応形式: {', '.join(SUPPORTED_EXTENSIONS)}"

    try:
        progress(0.1, desc="ファイルを読み込んでいます...")

        with tempfile.TemporaryDirectory() as tmpdir:
            audio_path = file_path

            if file_ext in VIDEO_EXTENSIONS:
                progress(0.2, desc="動画から音声を抽出しています...")
                audio_path = os.path.join(tmpdir, "audio.wav")
                extract_audio_from_video(file_path, audio_path)

            progress(0.3, desc=f"Whisperモデル ({model_name}) を読み込んでいます...")
            model = whisper.load_model(model_name)

            progress(0.5, desc="音声を文字起こししています（ファイルサイズにより時間がかかります）...")
            transcribe_options = {"verbose": False}
            if language:
                transcribe_options["language"] = language

            result = model.transcribe(audio_path, **transcribe_options)
            segments = result["segments"]
            detected_lang = result.get("language", "不明")

            progress(0.9, desc="字幕ファイルを生成しています...")

            if output_format == "srt":
                subtitle_text = segments_to_srt(segments)
                ext = "srt"
            elif output_format == "vtt":
                subtitle_text = segments_to_vtt(segments)
                ext = "vtt"
            else:
                subtitle_text = segments_to_txt(segments)
                ext = "txt"

            original_name = Path(file_path).stem
            output_filename = f"{original_name}_subtitle.{ext}"
            output_path = os.path.join(tempfile.gettempdir(), output_filename)
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(subtitle_text)

            progress(1.0, desc="完了しました！")

            status = (
                f"字幕生成完了！\n"
                f"- 検出言語: {detected_lang}\n"
                f"- セグメント数: {len(segments)}\n"
                f"- 出力形式: {output_format.upper()}"
            )
            return subtitle_text, output_path, status

    except FileNotFoundError as e:
        if "ffmpeg" in str(e):
            return "", None, "エラー: ffmpegがインストールされていません。"
        return "", None, f"エラー: ファイルが見つかりません: {e}"
    except Exception as e:
        return "", None, f"エラーが発生しました: {str(e)}"


def build_ui():
    with gr.Blocks(title="自動字幕生成システム", theme=gr.themes.Soft()) as demo:
        gr.Markdown(
            "# 自動字幕生成システム\n音声・動画ファイルをアップロードするだけで、AIが自動的に字幕を生成します。"
        )

        with gr.Row():
            with gr.Column(scale=1):
                gr.Markdown("### 設定")
                file_input = gr.File(
                    label="音声・動画ファイルをアップロード",
                    file_types=AUDIO_EXTENSIONS + VIDEO_EXTENSIONS,
                    type="filepath",
                )
                model_dropdown = gr.Dropdown(
                    choices=list(MODEL_OPTIONS.keys()),
                    value="small（バランス良好）",
                    label="精度モデルを選択",
                    info="精度が高いほど時間がかかります",
                )
                language_dropdown = gr.Dropdown(
                    choices=list(LANGUAGE_OPTIONS.keys()),
                    value="自動検出",
                    label="言語を選択",
                    info="わからない場合は「自動検出」を選んでください",
                )
                format_radio = gr.Radio(
                    choices=["srt", "vtt", "txt"],
                    value="srt",
                    label="出力形式を選択",
                    info="SRT: 多くの動画ソフト対応 / VTT: Web動画向け / TXT: テキストのみ",
                )
                generate_btn = gr.Button("字幕を生成する", variant="primary", size="lg")

            with gr.Column(scale=2):
                gr.Markdown("### 結果")
                status_box = gr.Textbox(
                    label="ステータス",
                    lines=4,
                    interactive=False,
                    placeholder="字幕生成が完了するとここに結果が表示されます",
                )
                subtitle_output = gr.Textbox(
                    label="生成された字幕",
                    lines=15,
                    interactive=False,
                    placeholder="字幕テキストがここに表示されます",
                )
                download_btn = gr.File(label="字幕ファイルをダウンロード", interactive=False)

        gr.Markdown(
            """
            ### 使い方
            1. **ファイルをアップロード**: 音声（MP3, WAV等）または動画（MP4, MOV等）をドラッグ＆ドロップ
            2. **モデルを選択**: 最初は「small（バランス良好）」がおすすめです
            3. **言語を選択**: 日本語の場合は「日本語」を選ぶと精度が上がります
            4. **形式を選択**: 動画編集ソフトで使う場合は「srt」を選んでください
            5. **「字幕を生成する」ボタンをクリック**
            """
        )

        def on_generate(file_obj, model_display, language_display, output_format, progress=gr.Progress()):
            model_name = MODEL_OPTIONS.get(model_display, "small")
            language = LANGUAGE_OPTIONS.get(language_display, None)
            return generate_subtitles(file_obj, model_name, language, output_format, progress)

        generate_btn.click(
            fn=on_generate,
            inputs=[file_input, model_dropdown, language_dropdown, format_radio],
            outputs=[subtitle_output, download_btn, status_box],
        )

    return demo


if __name__ == "__main__":
    demo = build_ui()
    demo.launch(server_name="0.0.0.0", server_port=7860, share=False, inbrowser=True)
APPEOF
fi

# セットアップ（初回のみ）
if [ ! -d "venv" ]; then
    echo "初回セットアップ中です（数分かかります）..."
    python3 -m venv venv
    source venv/bin/activate
    pip install --quiet --upgrade pip
    pip install --quiet openai-whisper gradio imageio-ffmpeg
    echo "セットアップ完了！"
else
    source venv/bin/activate
fi

# imageio_ffmpegのバイナリをvenv/binにffmpegとしてリンク
FFMPEG_EXE=$(python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())" 2>/dev/null)
if [ -n "$FFMPEG_EXE" ]; then
    ln -sf "$FFMPEG_EXE" venv/bin/ffmpeg
fi

export PYTHONHTTPSVERIFY=0
export REQUESTS_CA_BUNDLE=""
export CURL_CA_BUNDLE=""

kill $(lsof -ti:7860) 2>/dev/null
echo "起動中... ブラウザが自動で開きます"
sleep 1 && open http://localhost:7860 &
python app.py

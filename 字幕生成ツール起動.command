#!/bin/bash
# このファイルをダブルクリックするだけで起動します（Mac用）

cd "$(dirname "$0")"

# app.py を自動生成
cat > app.py << 'APPEOF'
import os, tempfile, subprocess, ssl, urllib.request
from pathlib import Path
import imageio_ffmpeg
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

# SSL証明書エラーの回避
ssl._create_default_https_context = ssl._create_unverified_context
os.environ["PYTHONHTTPSVERIFY"] = "0"
os.environ["REQUESTS_CA_BUNDLE"] = ""
os.environ["CURL_CA_BUNDLE"] = ""

import whisper
import gradio as gr

AUDIO_EXT = [".mp3",".wav",".m4a",".aac",".flac",".ogg",".wma"]
VIDEO_EXT = [".mp4",".mov",".avi",".mkv",".webm",".wmv",".flv"]
MODELS = {"tiny（最速・低精度）":"tiny","base（速い・標準精度）":"base","small（バランス良好）":"small","medium（高精度）":"medium","large（最高精度・低速）":"large"}
LANGS = {"自動検出":None,"日本語":"ja","英語":"en","中国語":"zh","韓国語":"ko","フランス語":"fr","ドイツ語":"de","スペイン語":"es"}

def ts(s):
    return f"{int(s//3600):02d}:{int((s%3600)//60):02d}:{int(s%60):02d},{int((s%1)*1000):03d}"

def to_srt(segs):
    return "\n".join(f"{i}\n{ts(s['start'])} --> {ts(s['end'])}\n{s['text'].strip()}\n" for i,s in enumerate(segs,1))

def to_vtt(segs):
    return "WEBVTT\n\n" + "\n".join(f"{i}\n{ts(s['start']).replace(',','.')} --> {ts(s['end']).replace(',','.')}\n{s['text'].strip()}\n" for i,s in enumerate(segs,1))

def to_txt(segs):
    return "\n".join(f"[{ts(s['start'])} --> {ts(s['end'])}] {s['text'].strip()}" for s in segs)

def run(file, model_label, lang_label, fmt, progress=gr.Progress()):
    if file is None:
        return "", None, "ファイルをアップロードしてください。"
    path = file.name
    ext = Path(path).suffix.lower()
    if ext not in AUDIO_EXT + VIDEO_EXT:
        return "", None, "対応していないファイル形式です。"
    try:
        progress(0.2, desc="準備中...")
        audio = path
        with tempfile.TemporaryDirectory() as tmp:
            if ext in VIDEO_EXT:
                progress(0.3, desc="動画から音声を取り出しています...")
                audio = os.path.join(tmp, "audio.wav")
                r = subprocess.run([FFMPEG,"-i",path,"-vn","-acodec","pcm_s16le","-ar","16000","-ac","1","-y",audio], capture_output=True)
                if r.returncode != 0:
                    return "", None, "動画の処理に失敗しました。ffmpegをインストールしてください。"
            progress(0.4, desc="AIモデルを読み込んでいます...")
            model = whisper.load_model(MODELS.get(model_label, "small"))
            progress(0.6, desc="文字起こし中です（しばらくお待ちください）...")
            opts = {"verbose": False}
            lang = LANGS.get(lang_label)
            if lang: opts["language"] = lang
            result = model.transcribe(audio, **opts)
            segs = result["segments"]
            progress(0.9, desc="字幕ファイルを作成しています...")
            text = to_srt(segs) if fmt=="srt" else to_vtt(segs) if fmt=="vtt" else to_txt(segs)
            out = os.path.join(tempfile.gettempdir(), Path(path).stem + f"_字幕.{fmt}")
            open(out,"w",encoding="utf-8").write(text)
            progress(1.0, desc="完了！")
            return text, out, f"完了！\n検出言語: {result.get('language','不明')}\nセグメント数: {len(segs)}"
    except Exception as e:
        return "", None, f"エラー: {e}"

with gr.Blocks(title="自動字幕生成", theme=gr.themes.Soft()) as app:
    gr.Markdown("# 自動字幕生成ツール\n動画・音声ファイルをドロップするだけで字幕を作成します。")
    with gr.Row():
        with gr.Column(scale=1):
            f = gr.File(label="ファイルをここにドロップ", file_types=AUDIO_EXT+VIDEO_EXT, type="filepath")
            m = gr.Dropdown(list(MODELS.keys()), value="small（バランス良好）", label="精度")
            l = gr.Dropdown(list(LANGS.keys()), value="自動検出", label="言語")
            fmt = gr.Radio(["srt","vtt","txt"], value="srt", label="出力形式")
            btn = gr.Button("字幕を生成する", variant="primary", size="lg")
        with gr.Column(scale=2):
            status = gr.Textbox(label="状態", lines=3, interactive=False)
            preview = gr.Textbox(label="字幕プレビュー", lines=12, interactive=False)
            dl = gr.File(label="ダウンロード", interactive=False)
    btn.click(run, [f,m,l,fmt], [preview,dl,status])

app.launch(server_name="0.0.0.0", server_port=7860, inbrowser=True)
APPEOF

# セットアップ
if [ ! -d "venv" ]; then
    echo "初回セットアップ中です（数分かかります）..."
    python3 -m venv venv
fi
source venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet openai-whisper gradio imageio-ffmpeg
echo "セットアップ完了！"

echo "起動中... ブラウザが自動で開きます"
export PYTHONHTTPSVERIFY=0
export REQUESTS_CA_BUNDLE=""
export CURL_CA_BUNDLE=""
kill $(lsof -ti:7860) 2>/dev/null
sleep 1 && open http://localhost:7860 &
python app.py

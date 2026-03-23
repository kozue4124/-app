#!/bin/bash
# このファイルをダブルクリックするだけで起動します（Mac用）

cd "$(dirname "$0")"

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
FFMPEG_EXE=$(python -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())")
ln -sf "$FFMPEG_EXE" venv/bin/ffmpeg

export PYTHONHTTPSVERIFY=0
export REQUESTS_CA_BUNDLE=""
export CURL_CA_BUNDLE=""

kill $(lsof -ti:7860) 2>/dev/null
echo "起動中... ブラウザが自動で開きます"
sleep 1 && open http://localhost:7860 &
python app.py

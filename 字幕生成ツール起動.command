#!/bin/bash
# このファイルをダブルクリックするとアプリが起動します（Mac用）

# このスクリプトがあるフォルダに移動
cd "$(dirname "$0")"

# 初回セットアップ（venvがなければ自動でインストール）
if [ ! -d "venv" ]; then
    echo "初回セットアップ中です。数分かかります..."
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    echo "セットアップ完了！"
else
    source venv/bin/activate
fi

# ブラウザを自動で開く
sleep 2 && open http://localhost:7860 &

echo "アプリを起動しています..."
echo "ブラウザで http://localhost:7860 が開きます"
echo "終了するにはこのウィンドウを閉じてください"
python app.py

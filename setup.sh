#!/bin/bash
# 自動字幕生成システム セットアップスクリプト

set -e

echo "======================================"
echo "  自動字幕生成システム セットアップ"
echo "======================================"
echo ""

# Python バージョン確認
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python バージョン: $python_version"

# ffmpeg のインストール確認
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg をインストールしています..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install ffmpeg
        else
            echo "エラー: Homebrewがインストールされていません。"
            echo "https://brew.sh/ からインストールしてください。"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        sudo apt-get update && sudo apt-get install -y ffmpeg
    else
        echo "警告: ffmpegを手動でインストールしてください。"
        echo "Windows: https://ffmpeg.org/download.html"
    fi
else
    echo "ffmpeg: インストール済み"
fi

# 仮想環境の作成（任意）
if [ ! -d "venv" ]; then
    echo ""
    echo "Python仮想環境を作成しています..."
    python3 -m venv venv
fi

# 仮想環境の有効化
echo "仮想環境を有効化しています..."
source venv/bin/activate

# 依存ライブラリのインストール
echo ""
echo "依存ライブラリをインストールしています..."
pip install --upgrade pip
pip install -r requirements.txt

echo ""
echo "======================================"
echo "  セットアップ完了！"
echo "======================================"
echo ""
echo "アプリを起動するには以下のコマンドを実行してください:"
echo ""
echo "  source venv/bin/activate"
echo "  python app.py"
echo ""
echo "ブラウザで http://localhost:7860 を開いてください。"
echo ""

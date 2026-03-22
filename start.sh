#!/bin/bash
# 自動字幕生成システム 起動スクリプト

echo "自動字幕生成システムを起動しています..."

# 仮想環境が存在する場合は有効化
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# アプリ起動
python app.py

@echo off
chcp 65001 > nul
cd /d "%~dp0"

echo 字幕生成ツールを起動しています...

if not exist "venv" (
    echo 初回セットアップ中です。数分かかります...
    python -m venv venv
    call venv\Scripts\activate.bat
    pip install --upgrade pip
    pip install -r requirements.txt
    echo セットアップ完了！
) else (
    call venv\Scripts\activate.bat
)

start "" http://localhost:7860
python app.py
pause

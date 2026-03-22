# 自動字幕生成システム

音声・動画ファイルをアップロードするだけで、AIが自動的に字幕を生成するWebアプリです。
OpenAIの [Whisper](https://github.com/openai/whisper) を使用し、100以上の言語に対応しています。

---

## 画面イメージ

```
┌─────────────────────────────────────────────────────┐
│            自動字幕生成システム                        │
├──────────────────┬──────────────────────────────────┤
│ 設定             │ 結果                              │
│                  │                                   │
│ [ファイルを       │ ステータス:                        │
│  アップロード]    │ 字幕生成完了！ 検出言語: ja        │
│                  │                                   │
│ モデル: small    │ 生成された字幕:                    │
│ 言語: 日本語     │ 1                                 │
│ 形式: srt        │ 00:00:01,000 --> 00:00:03,500     │
│                  │ こんにちは、今日は...              │
│ [字幕を生成する] │                                   │
│                  │ [字幕ファイルをダウンロード]        │
└──────────────────┴──────────────────────────────────┘
```

---

## 必要なもの

- **Python 3.8以上**
- **ffmpeg**（動画ファイルを処理する場合）
- インターネット接続（初回のモデルダウンロード時）

---

## セットアップ方法

### 1. このリポジトリをダウンロード

```bash
git clone <リポジトリURL>
cd auto-subtitle-generator
```

### 2. セットアップスクリプトを実行

**Mac / Linux:**
```bash
chmod +x setup.sh
./setup.sh
```

**Windows（PowerShell）:**
```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

---

## 起動方法

**Mac / Linux:**
```bash
./start.sh
```

**Windows:**
```powershell
.\venv\Scripts\Activate.ps1
python app.py
```

ブラウザで **http://localhost:7860** を開いてください。

---

## 使い方

1. **ファイルをアップロード**
   音声（MP3, WAV等）または動画（MP4, MOV等）をドラッグ＆ドロップします。

2. **精度モデルを選択**
   | モデル | 速度 | 精度 | 用途 |
   |--------|------|------|------|
   | tiny   | 最速 | 低   | テスト用 |
   | base   | 速い | 標準 | 短い動画 |
   | small  | 普通 | 良好 | **おすすめ** |
   | medium | 遅い | 高   | 重要な動画 |
   | large  | 最遅 | 最高 | 高品質が必要な場合 |

3. **言語を選択**
   わからない場合は「自動検出」のままでOKです。
   日本語と指定すると精度が上がります。

4. **出力形式を選択**
   - `srt` : Adobe Premiere Pro, DaVinci Resolve など多くの動画編集ソフト対応
   - `vtt` : YouTube, Webサイト向け
   - `txt` : テキストのみ（タイムスタンプ付き）

5. **「字幕を生成する」をクリック**
   完了したらダウンロードボタンが表示されます。

---

## 対応ファイル形式

| 種類 | 対応形式 |
|------|---------|
| 音声 | MP3, WAV, M4A, AAC, FLAC, OGG, WMA |
| 動画 | MP4, MOV, AVI, MKV, WebM, WMV, FLV |

---

## よくある質問

**Q: 初回起動が遅い**
A: 初回はWhisperのモデルをダウンロードするため時間がかかります。2回目以降は速くなります。

**Q: 動画ファイルが処理できない**
A: ffmpegがインストールされているか確認してください。`setup.sh` を実行すると自動インストールされます。

**Q: 精度が低い**
A: モデルを `medium` や `large` に変更するか、言語を手動で指定してみてください。

**Q: GPUを使いたい**
A: CUDAが利用可能な場合、Whisperは自動的にGPUを使用します。
   PyTorchのCUDA版が必要です: `pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118`

# hex-zh-hant

讓 **Hex**（Anomaly 的本機語音聽寫工具）在 Windows 與 macOS 上安裝好，並且把**聽寫輸出的中文改成繁體（台灣用語）**。

> Hex 內建只有介面語言的繁體中文，**聽寫文字本身沒有簡轉繁**。
> 官方說明：沒有任何模型能穩定選對字形（[#1835](https://github.com/anomalyco/hex/issues/1835)），
> 而官方認可的解法是 `hex.config.ts` 的自訂轉換（[#829](https://github.com/anomalyco/hex/issues/829)）。
> 這個 repo 就是把那條路鋪成一鍵腳本。

---

## 給 Agent 的指令（先讀 `AGENTS.md`）

**Windows（PowerShell）：**

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/peliter/hex-zh-hant/main/install-windows.ps1 -OutFile i.ps1; ./i.ps1"
```

**macOS（Terminal）：**

```bash
curl -fsSL https://raw.githubusercontent.com/peliter/hex-zh-hant/main/install-macos.sh | bash
```

驗證成功的三個條件：

1. `hex commands check` 輸出含 `3 transformations`
2. `hex settings get ui_language` 輸出 `zh-Hant`
3. `hex settings get dictation_processing.default_mode` 內含 `s2twp`

## 給人的安裝方式

### Windows

```powershell
# 方法一：一行（腳本會自行下載轉換器）
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/peliter/hex-zh-hant/main/install-windows.ps1 -OutFile i.ps1; ./i.ps1"

# 方法二：clone 後執行
git clone https://github.com/peliter/hex-zh-hant
cd hex-zh-hant
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

參數：

| 參數 | 說明 |
|---|---|
| `-Hotkey control+option+space` | 聽寫快捷鍵（預設 `Ctrl+Alt+Space`） |
| `-SkipHotkey` | 不動你現有的快捷鍵 |
| `-ConfigureOnly` | 只改設定，不啟動／不安裝 Hex |

### macOS（Apple Silicon / macOS 15+）

```bash
# 方法一：一行（透過 Homebrew 安裝 Hex 並設定轉換器）
curl -fsSL https://raw.githubusercontent.com/peliter/hex-zh-hant/main/install-macos.sh | bash

# 方法二：clone 後執行
git clone https://github.com/peliter/hex-zh-hant
cd hex-zh-hant
chmod +x ./install-macos.sh
./install-macos.sh
```

參數：

| 參數 | 說明 |
|---|---|
| `--hotkey control+option+space` | 聽寫快捷鍵（預設 `⌃⌥Space`，亦可改 `right-command` 等） |
| `--skip-hotkey` | 不動你現有的快捷鍵 |
| `--configure-only` | 只改設定，不啟動／不安裝 Hex |

## 腳本做了什麼

| 步驟 | 內容 |
|---|---|
| 1 | 若本機尚未安裝 Hex：Windows 執行官方 `install-windows.ps1`（驗證檔案大小、SHA-256 與簽章）；macOS 透過 `brew install --cask anomalyco/tap/hex` 安裝 |
| 2 | 啟動再關閉 Hex，讓它把 `settings.json` 寫完整 |
| 3 | `hex commands init` 建立 `~/.config/hex`，放入 OpenCC `s2tw`／`s2twp` 轉換器 |
| 4 | **關閉 Hex 後**改 `settings.json`（Windows：`%APPDATA%\hex\settings.json`；macOS：`~/Library/Application Support/hex/settings.json`），把 `s2twp` 加進「每次聽寫」的步驟（Hex 執行中會覆寫設定，必須先關） |
| 5 | 重新啟動 Hex，設定 `ui_language = zh-Hant` 與避開輸入法衝突的快捷鍵 |
| 6 | 印出驗證結果 |

## 為什麼預設熱鍵是 Ctrl+Alt+Space

Hex 預設 `Ctrl+Space`，但那是 Windows 注音／新注音的**中英切換**，兩者會互撞。
`Ctrl+Alt+Space` 不衝突；想換成 `caps-lock` 或 `f5` 也可以：`-Hotkey caps-lock`。

## 轉換效果

| 模型輸出（簡體） | Hex 貼出（s2twp） |
|---|---|
| 这个软件里的内存和硬盘都很慢 | 這個**軟體**裡的**記憶體**和**硬碟**都很慢 |
| 数据库的网络连接断开了 | **資料庫**的**網路連線**斷開了 |
| 头发被台风吹乱了，一只狗跑过来 | **頭髮**被**颱風**吹亂了，**一隻**狗跑過來 |
| U盘里有资料 | **隨身碟**裡有資料 |

## 驗證方式

```powershell
hex commands check                        # 3 transformations
hex settings get ui_language              # zh-Hant

# 講一句話之後：
hex history --raw --limit 1               # raw_text 是簡體，final_text 應為繁體
```

⚠️ **不要用 Hex 的「試試」欄位驗證**：那個預覽只套用內建步驟，腳本轉換只在真的聽寫時執行。

## 已知限制

- 轉換是**聽完之後**處理：即時字幕（Labs › Live text）的預覽仍是簡體，貼出的最終文字才是繁體。
- 「每次聽寫」是全域預設；你自建的**每個 App 模式要各自再加一次** `s2twp`。
- 依賴 OpenCC 的字典（Apache-2.0），字詞判斷以台灣用語為主；專有名詞建議加進 Hex 的 Vocabulary。
- Linux 尚無一鍵安裝腳本，可手動照「手動步驟」做，路徑同為 `~/.config/hex`。

## 手動步驟（不想跑腳本）

```powershell
# 1. 安裝 Hex（官方）
powershell -ExecutionPolicy Bypass -Command "iwr https://anoma.ly/hex/install-windows.ps1 -OutFile i.ps1; ./i.ps1"

# 2. 建立轉換器工作區
hex commands init

# 3. 把 transformer/ 底下的 4 個 .ts 複製到 %USERPROFILE%\.config\hex
#    hex.config.ts, hex-s2tw.ts, hex-data-st.ts, hex-data-tw.ts
hex commands check

# 4. 完全關閉 Hex（工作列圖示 → Quit），再編輯
#    %APPDATA%\hex\settings.json
#    dictation_processing.default_mode.transformations 加入 "s2twp"

# 5. 重開 Hex
```

## 移除

```powershell
# 只移除繁中轉換
Remove-Item "$env:USERPROFILE\.config\hex\hex-s2tw.ts","$env:USERPROFILE\.config\hex\hex-data-st.ts","$env:USERPROFILE\.config\hex\hex-data-tw.ts"
# 再到 settings.json 把 "s2twp" 從步驟移除（先關 Hex）

# 連 Hex 一起移除（用官方安裝腳本的反安裝）
iwr https://anoma.ly/hex/install-windows.ps1 -OutFile uninstall-hex.ps1
powershell -ExecutionPolicy Bypass -File .\uninstall-hex.ps1 -Uninstall
```

## 授權

本 repo 的腳本與說明為 Apache-2.0。轉換器與字典資料來自 OpenCC（Apache-2.0）與
[truelife2/opencode-hex3-transformer-s2tw](https://github.com/truelife2/opencode-hex3-transformer-s2tw)，
詳見 `NOTICE.md`。Hex 本身為 Anomaly 的 MIT 授權專案。

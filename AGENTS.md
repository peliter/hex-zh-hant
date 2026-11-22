# AGENTS.md

Instructions for an AI agent that lands in this repository. Read this file before
running anything. Everything here is idempotent: running it twice is safe.

## Goal

Hex is a local dictation app (Anomaly, MIT). It ships a Traditional Chinese
*interface*, but its **transcripts are whatever script the speech model picks** —
in practice Simplified. There is no built-in simplified-to-traditional step
(upstream: anomalyco/hex#1835, open, `needs-design`). The supported workaround
(upstream maintainer, anomalyco/hex#829) is a **personal transformation** in
`~/.config/hex/hex.config.ts`.

This repository installs Hex and that transformation, then wires the step into
"Every dictation".

## Requirements

- **Windows**: Windows 10/11 (x64 or ARM64), PowerShell 5.1+, network access to `anoma.ly` and `raw.githubusercontent.com`, microphone permission
- **macOS**: macOS 15+ on Apple Silicon, Homebrew (`brew install --cask anomalyco/tap/hex`), microphone & Accessibility permissions

## Run

Windows:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/peliter/hex-zh-hant/main/install-windows.ps1 -OutFile i.ps1; ./i.ps1"
```

Or, from a clone: `powershell -ExecutionPolicy Bypass -File .\install-windows.ps1`

Useful switches: `-SkipHotkey`, `-ConfigureOnly`, `-Hotkey caps-lock`.

macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/peliter/hex-zh-hant/main/install-macos.sh | bash
```

Or, from a clone: `chmod +x ./install-macos.sh && ./install-macos.sh`

Useful flags: `--skip-hotkey`, `--configure-only`, `--hotkey right-command`.

With no path to the install script (offline agent), do the "Manual steps"
in `README.md` instead.

## What the script mutates

| Path | Change |
|---|---|
| `%APPDATA%\hex\` (Windows) / `/Applications/Hex.app` (macOS) | Hex install |
| `%USERPROFILE%\.config\hex\` / `~/.config/hex/` | `hex.config.ts` + 3 transformer `.ts` files, `hex.d.ts`, `tsconfig.json` (via `hex commands init`) |
| `%APPDATA%\hex\settings.json` / `~/Library/Application Support/hex/settings.json` | `dictation_processing.default_mode.transformations` gains `s2twp`; `ui_language = zh-Hant`; `dictation_hotkey` (unless skipped) |
| `settings.json.bak-<timestamp>` | Backup written before the edit |
| HKCU user `PATH` (Windows) | Hex's own installer appends `%APPDATA%\hex\bin` |

It does **not** touch other apps' config, the registry beyond Hex's own keys, or
any network service besides the two hosts above.

## Success criteria — check, do not assume

```powershell
hex commands check                            # must contain: 3 transformations
hex settings get ui_language                  # must be: zh-Hant
hex settings get dictation_processing.default_mode   # must contain: s2twp
hex settings get dictation_hotkey             # e.g. control+option+space
```

Then verify the pipeline end to end: have the user dictate one Chinese sentence,
and compare

```powershell
hex history --raw --limit 1
```

`raw_text` stays Simplified (model output); `final_text` must be Traditional
(e.g. 軟體 / 記憶體 / 硬碟 / 網路 / 資料庫). Different scripts in the two fields
is the proof the transformation ran.

## Guardrails

- **Never edit `settings.json` while Hex is running.** Hex rewrites it on exit and
  the edit is lost. Quit first (`hex quit`), wait ~2 s, then edit.
- **Do not use the Output pane's "Try" field to verify.** Its preview only applies
  *built-in* steps (`lowercase`, …); script transformations run only on a real
  dictation.
- **Do not report success from the script's exit code alone.** Require the three
  checks above.
- **Per-mode steps are independent.** If the user creates an app-specific mode, it
  needs `s2twp` added separately.
- **Live text previews stay Simplified.** The step is post-processing; only the
  pasted result is Traditional.
- Do not add `fetch`/`child_process` to `hex.config.ts`. That would make Hex show a
  trust prompt and, until allowed, paste text unchanged.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `hex commands check` prints "no hex.config.ts or hex.config.js" | workspace missing / wrong dir | `hex commands init`, then re-copy the 4 `.ts` files |
| `unknown setting` from `hex settings set` | nested keys are not settable | edit `settings.json` with Hex closed |
| Pane shows "還沒有步驟" after install | Hex cached settings before the edit | `hex restart` |
| Output still Simplified | step missing, or a different app mode is active | check `dictation_processing.default_mode` / the mode's own `transformations` |
| Hotkey does nothing | `Ctrl+Space` grabbed by the Chinese IME | `hex settings set dictation_hotkey control+option+space` |
| Hex reports version/binary mismatch on install | a running Hex held the old binary | quit Hex, re-run the installer |

## Attribution

The transformer and dictionaries are OpenCC (Apache-2.0) data packaged by
`truelife2/opencode-hex3-transformer-s2tw`. Keep `NOTICE.md` and the Apache-2.0
license text when redistributing.

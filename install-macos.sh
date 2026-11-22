#!/usr/bin/env bash
set -euo pipefail

# Installs Hex on macOS and makes its dictation output Traditional Chinese (Taiwan).
#
# Usage:
#   ./install-macos.sh [--hotkey <key>] [--skip-hotkey] [--configure-only]

HOTKEY="control+option+space"
SKIP_HOTKEY=false
CONFIGURE_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hotkey)
      if [[ $# -lt 2 ]]; then
        echo "Error: --hotkey requires a value" >&2
        exit 1
      fi
      HOTKEY="$2"
      shift 2
      ;;
    --skip-hotkey)
      SKIP_HOTKEY=true
      shift
      ;;
    --configure-only)
      CONFIGURE_ONLY=true
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: install-macos.sh [options]

Options:
  --hotkey <key>     Dictation shortcut (default: control+option+space)
  --skip-hotkey      Leave existing dictation shortcut unchanged
  --configure-only   Only write config and patch settings (Hex must be installed)
  -h, --help         Show this help message
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

REPO_OWNER="peliter"
REPO_NAME="hex-zh-hant"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/transformer"

TRANSFORMER_FILES=(
  "hex.config.ts"
  "hex-s2tw.ts"
  "hex-data-st.ts"
  "hex-data-tw.ts"
)

SUPPORT_DIR="${HOME}/Library/Application Support/hex"
SETTINGS_PATH="${SUPPORT_DIR}/settings.json"
CONFIG_DIR="${HOME}/.config/hex"

step() { printf '\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '\033[32m    %s\033[0m\n' "$1"; }
warn() { printf '\033[33m    %s\033[0m\n' "$1" >&2; }

find_hex_bin() {
  if command -v hex >/dev/null 2>&1; then
    command -v hex
    return 0
  fi
  local candidates=(
    "/Applications/Hex.app/Contents/MacOS/hex"
    "${HOME}/Applications/Hex.app/Contents/MacOS/hex"
  )
  local c
  for c in "${candidates[@]}"; do
    if [[ -x "$c" ]]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

start_hex() {
  local hex_bin="$1"
  if "$hex_bin" status >/dev/null 2>&1; then
    return 0
  fi
  if [[ -d "/Applications/Hex.app" ]]; then
    open -a "/Applications/Hex.app"
  elif [[ -d "${HOME}/Applications/Hex.app" ]]; then
    open -a "${HOME}/Applications/Hex.app"
  else
    "$hex_bin" start >/dev/null 2>&1 &
  fi

  local i
  for i in $(seq 1 40); do
    sleep 0.5
    if "$hex_bin" status >/dev/null 2>&1; then
      return 0
    fi
  done
  warn "Hex did not answer within 20 s; carrying on."
}

quit_hex() {
  local hex_bin="$1"
  "$hex_bin" quit >/dev/null 2>&1 || true
  sleep 2
  pkill -x "Hex" >/dev/null 2>&1 || true
  pkill -x "hex" >/dev/null 2>&1 || true
  sleep 1
}

# ---------------------------------------------------------------------------
# 1. Hex itself
# ---------------------------------------------------------------------------
if ! HEX_BIN="$(find_hex_bin)"; then
  if [[ "$CONFIGURE_ONLY" == true ]]; then
    echo "Hex is not installed and --configure-only was given." >&2
    exit 1
  fi
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed. Install Homebrew or download Hex from https://anoma.ly/hex first." >&2
    exit 1
  fi
  step "Installing Hex via Homebrew"
  brew install --cask anomalyco/tap/hex
  HEX_BIN="$(find_hex_bin)" || {
    echo "Hex installation finished but hex CLI was not found." >&2
    exit 1
  }
  ok "installed ${HEX_BIN}"
fi

# ---------------------------------------------------------------------------
# 2. Let Hex write its own settings, then close it before we patch them
# ---------------------------------------------------------------------------
step "Starting and quitting Hex so settings.json is complete"
if [[ "$CONFIGURE_ONLY" == false ]]; then
  start_hex "$HEX_BIN"
  if [[ ! -f "$SETTINGS_PATH" ]]; then
    "$HEX_BIN" settings set ui_language zh-Hant >/dev/null 2>&1 || true
  fi
  sleep 2
fi
quit_hex "$HEX_BIN"

if [[ ! -f "$SETTINGS_PATH" ]]; then
  echo "${SETTINGS_PATH} is missing. Run Hex once by hand, then run this script again." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 3. The transformer workspace
# ---------------------------------------------------------------------------
step "Installing the OpenCC transformer into ${CONFIG_DIR}"
mkdir -p "$CONFIG_DIR"
"$HEX_BIN" commands init >/dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_TRANSFORMER="${SCRIPT_DIR}/transformer"

for name in "${TRANSFORMER_FILES[@]}"; do
  target="${CONFIG_DIR}/${name}"
  source="${LOCAL_TRANSFORMER}/${name}"
  if [[ -f "$source" ]]; then
    cp -f "$source" "$target"
  else
    curl -fsSL "${RAW_BASE}/${name}" -o "$target"
  fi
done

CHECK_OUT="$("$HEX_BIN" commands check 2>&1)"
ok "$CHECK_OUT"
if [[ "$CHECK_OUT" != *"transformations"* ]]; then
  echo "hex commands check did not report any transformations: ${CHECK_OUT}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. settings.json: add the step (Hex is closed, so this sticks)
# ---------------------------------------------------------------------------
step "Adding the s2twp step to Every dictation"
BACKUP="${SETTINGS_PATH}.bak-$(date +%Y%m%d-%H%M%S)"
cp -f "$SETTINGS_PATH" "$BACKUP"
ok "settings backed up to ${BACKUP}"

if command -v python3 >/dev/null 2>&1; then
  STEPS_OUT="$(python3 - "$SETTINGS_PATH" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

dp = data.setdefault("dictation_processing", {})
mode = dp.setdefault("default_mode", {})
steps = [s for s in mode.get("transformations", []) if s]
if "s2twp" not in steps:
    steps.append("s2twp")
mode["transformations"] = steps

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(", ".join(steps))
PY
)"
elif command -v node >/dev/null 2>&1; then
  STEPS_OUT="$(node - "$SETTINGS_PATH" <<'JS'
const fs = require("fs");
const path = process.argv[2];
const data = JSON.parse(fs.readFileSync(path, "utf8"));
data.dictation_processing = data.dictation_processing || {};
data.dictation_processing.default_mode = data.dictation_processing.default_mode || {};
const steps = (data.dictation_processing.default_mode.transformations || []).filter(Boolean);
if (!steps.includes("s2twp")) steps.push("s2twp");
data.dictation_processing.default_mode.transformations = steps;
fs.writeFileSync(path, JSON.stringify(data, null, 2) + "\n", "utf8");
console.log(steps.join(", "));
JS
)"
else
  STEPS_OUT="$(osascript -l JavaScript - "$SETTINGS_PATH" <<'JXA'
ObjC.import("Foundation");
function run(argv) {
  var path = argv[0];
  var raw = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  var data = JSON.parse(ObjC.unwrap(raw));
  data.dictation_processing = data.dictation_processing || {};
  data.dictation_processing.default_mode = data.dictation_processing.default_mode || {};
  var steps = (data.dictation_processing.default_mode.transformations || []).filter(Boolean);
  if (steps.indexOf("s2twp") === -1) steps.push("s2twp");
  data.dictation_processing.default_mode.transformations = steps;
  var out = $.NSString.stringWithString(JSON.stringify(data, null, 2) + "\n");
  out.writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
  return steps.join(", ");
}
JXA
)"
fi
ok "steps: ${STEPS_OUT}"

# ---------------------------------------------------------------------------
# 5. Start Hex and set what the CLI can set
# ---------------------------------------------------------------------------
if [[ "$CONFIGURE_ONLY" == false ]]; then
  step "Starting Hex"
  start_hex "$HEX_BIN"
  sleep 2

  step "Interface language -> zh-Hant"
  "$HEX_BIN" settings set ui_language zh-Hant >/dev/null

  if [[ "$SKIP_HOTKEY" == false && -n "$HOTKEY" ]]; then
    step "Dictation shortcut -> ${HOTKEY}"
    "$HEX_BIN" settings set dictation_hotkey "$HOTKEY" >/dev/null
  fi
fi

# ---------------------------------------------------------------------------
# 6. Report
# ---------------------------------------------------------------------------
step "Result"
"$HEX_BIN" settings get ui_language
"$HEX_BIN" settings get dictation_hotkey
"$HEX_BIN" settings get dictation_processing.default_mode

echo ""
echo "Done. Speak one sentence somewhere, then:"
echo "  ${HEX_BIN} history --raw --limit 1     # raw_text is simplified, final_text must be traditional"
echo "If the Output pane still shows no step, run: ${HEX_BIN} restart"

#!/data/data/com.termux/files/usr/bin/sh
# ============================================================
# patch-keyboard.sh — perbaikan keyboard HP di opencode (Termux)
# Masalah: opencode mengaktifkan mouse capture di TUI, jadi tap
# layar dikirim sebagai event mouse dan Termux tidak membuka
# keyboard. Script ini:
#   1. Matikan mouse capture opencode (tap layar = buka keyboard lagi)
#   2. Tambah tombol KEYBOARD di extra keys row Termux
#   3. Auto-show keyboard tiap opencode start (via termux-api)
# Idempotent — aman dijalankan berulang.
# ============================================================
set -e

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
PROPS="$HOME/.termux/termux.properties"
CONFIG="$HOME/.config/opencode/config.json"
LAUNCHER="$PREFIX/bin/opencode"

echo "[*] patch keyboard opencode"

# ------------------------------------------------------------
# 1. enable_mouse_capture: false di config opencode
# ------------------------------------------------------------
mkdir -p "$(dirname "$CONFIG")"
if ! grep -q '"enable_mouse_capture"' "$CONFIG" 2>/dev/null; then
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$CONFIG" <<'EOF'
import json, sys
p = sys.argv[1]
try:
    with open(p) as f:
        cfg = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cfg = {}
cfg["enable_mouse_capture"] = False
with open(p, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
print("config ditulis:", p)
EOF
  elif [ ! -s "$CONFIG" ]; then
    echo '{"enable_mouse_capture": false}' > "$CONFIG"
    echo "[*] config baru ditulis: $CONFIG"
  else
    echo "[!] config sudah berisi data dan python3 tidak tersedia."
    echo "    Tambah manual: \"enable_mouse_capture\": false di $CONFIG"
    echo "    atau: pkg install -y python"
  fi
else
  echo "[*] enable_mouse_capture sudah diatur di config"
fi

# ------------------------------------------------------------
# 2. Tombol KEYBOARD di extra keys row
# ------------------------------------------------------------
mkdir -p "$(dirname "$PROPS")"
touch "$PROPS"
if grep -q '^extra-keys' "$PROPS" && ! grep '^extra-keys' "$PROPS" | grep -q 'KEYBOARD'; then
  sed -i 's/^\(extra-keys = \[[^]]*\)\]$/\1 KEYBOARD]/' "$PROPS"
  echo "[*] KEYBOARD ditambahkan ke extra-keys"
elif ! grep -q '^extra-keys' "$PROPS"; then
  printf 'extra-keys = [ESC TAB CTRL ALT KEYBOARD]\n' >> "$PROPS"
  echo "[*] extra-keys dibuat dengan KEYBOARD"
else
  echo "[*] KEYBOARD sudah ada di extra-keys"
fi

# ------------------------------------------------------------
# 3. termux-api + auto-show di launcher opencode
# ------------------------------------------------------------
if ! command -v termux-keyboard-show >/dev/null 2>&1; then
  echo "[*] pasang termux-api ..."
  pkg install -y termux-api
fi
if [ -f "$LAUNCHER" ] && ! grep -q 'termux-keyboard-show' "$LAUNCHER"; then
  sed -i '/^unset LD_LIBRARY_PATH/a command -v termux-keyboard-show >/dev/null 2>\&1 \&\& termux-keyboard-show' "$LAUNCHER"
  echo "[*] auto-show keyboard ditanam ke $LAUNCHER"
else
  echo "[*] launcher sudah ber-auto-show (atau launcher tidak ditemukan)"
fi

# ------------------------------------------------------------
# 4. Reload + selesai
# ------------------------------------------------------------
command -v termux-reload-settings >/dev/null 2>&1 && termux-reload-settings
echo "[*] selesai. Restart opencode (atau Termux) lalu tes tap layar."

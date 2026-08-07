#!/data/data/com.termux/files/usr/bin/sh
# ============================================================
# patch-keyboard.sh — perbaikan keyboard HP di opencode (Termux)
# Masalah: opencode mengaktifkan mouse capture di TUI, jadi tap
# layar dikirim sebagai event mouse dan Termux tidak membuka
# keyboard. Script ini:
#   1. Matikan mouse capture TUI (tui.json: "mouse": false) dan
#      bersihkan key enable_mouse_capture yang salah di config.json
#   2. Tambah tombol KEYBOARD di extra keys row Termux
#   3. Auto-show keyboard tiap opencode start (via termux-api)
# Idempotent — aman dijalankan berulang.
# ============================================================
set -e

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
CONFIG="$HOME/.config/opencode/config.json"
TUI="$HOME/.config/opencode/tui.json"
PROPS="$HOME/.termux/termux.properties"
LAUNCHER="$PREFIX/bin/opencode"

echo "[*] patch keyboard opencode (rev 2)"

# ------------------------------------------------------------
# 1. Bersihkan key lama yang salah + matikan mouse capture TUI
# ------------------------------------------------------------
mkdir -p "$(dirname "$CONFIG")" "$(dirname "$TUI")"

if grep -q '"enable_mouse_capture"' "$CONFIG" 2>/dev/null; then
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$CONFIG" <<'EOF'
import json, sys
p = sys.argv[1]
try:
    with open(p) as f:
        cfg = json.load(f)
except json.JSONDecodeError:
    cfg = {}
cfg.pop("enable_mouse_capture", None)
with open(p, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
EOF
    echo "[*] key enable_mouse_capture dihapus dari config.json"
  elif [ "$(grep -o '"[a-z_]*":' "$CONFIG" | wc -l)" -le 1 ]; then
    echo '{}' > "$CONFIG"
    echo "[*] config.json direset (hanya berisi key yang salah)"
  else
    echo "[!] hapus manual: enable_mouse_capture di $CONFIG (atau: pkg install -y python)"
  fi
fi

if [ ! -f "$TUI" ]; then
  echo '{"mouse": false}' > "$TUI"
  echo "[*] tui.json dibuat dengan mouse off"
elif ! grep -q '"mouse"' "$TUI"; then
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$TUI" <<'EOF'
import json, sys
p = sys.argv[1]
try:
    with open(p) as f:
        t = json.load(f)
except json.JSONDecodeError:
    t = {}
t["mouse"] = False
with open(p, "w") as f:
    json.dump(t, f, indent=2)
    f.write("\n")
EOF
    echo "[*] mouse off ditambahkan ke tui.json"
  else
    echo "[!] tambah manual: \"mouse\": false di $TUI (atau: pkg install -y python)"
  fi
else
  echo "[*] mouse sudah diatur di tui.json"
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

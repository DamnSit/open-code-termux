#!/data/data/com.termux/files/usr/bin/sh
# ============================================================
# install-grun.sh — opencode (glibc aarch64) untuk Termux via glibc-runner
# Cara yang sama dengan claude-code-termux:
#   binary resmi build glibc + grun (glibc-runner, $PREFIX/glibc)
# Bonus: `opencode upgrade` berfungsi penuh (metode curl).
# ============================================================
set -e

INSTALLER_REV="2"

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
WORK="$HOME/.cache/opencode-grun"
BIN_DIR="$HOME/.opencode/bin"
BIN="$BIN_DIR/opencode"

ARCH="$(uname -m)"
[ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ] || { echo "[!] butuh aarch64, punya: $ARCH"; exit 1; }

mkdir -p "$WORK" "$BIN_DIR" "$PREFIX/bin"

# ------------------------------------------------------------
# 0. Versi: auto-detect terbaru dari npm, atau pin manual
#    dengan: VERSION=1.18.14 sh install-grun.sh
# ------------------------------------------------------------
if [ -z "${VERSION:-}" ]; then
  VERSION="$(curl -s --fail https://registry.npmjs.org/opencode-linux-arm64/latest \
             | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')"
  if [ -z "$VERSION" ]; then
    echo "[!] gagal deteksi versi terbaru. Pin manual: VERSION=1.18.14 sh install-grun.sh"
    exit 1
  fi
fi
echo "[*] installer grun rev $INSTALLER_REV — opencode $VERSION (glibc aarch64)"

# ------------------------------------------------------------
# 1. glibc-repo + glibc-runner (grun)
# ------------------------------------------------------------
if ! command -v grun >/dev/null 2>&1; then
  echo "[*] pasang glibc-repo + glibc-runner (sama seperti claude-code-termux) ..."
  pkg install -y glibc-repo
  pkg update
  pkg install -y glibc-runner
fi
if ! command -v grun >/dev/null 2>&1; then
  echo "[!] grun tidak ditemukan setelah pkg install. Periksa Termux versi F-Droid terbaru."
  exit 1
fi

# ------------------------------------------------------------
# 2. Binary resmi opencode (build glibc) dari npm registry,
#    diverifikasi terhadap shasum npm
# ------------------------------------------------------------
TGZ="$WORK/opencode-$VERSION.tgz"
if [ ! -f "$TGZ" ]; then
  echo "[*] unduh binary $VERSION (glibc) dari npm registry ..."
  curl -L --fail --retry 3 -o "$TGZ" \
    "https://registry.npmjs.org/opencode-linux-arm64/-/opencode-linux-arm64-$VERSION.tgz"
fi

NPM_SHA1="$(curl -s --fail "https://registry.npmjs.org/opencode-linux-arm64/$VERSION" \
            | sed -n 's/.*"shasum":"\([^"]*\)".*/\1/p')"
TGZ_SHA1="$(sha1sum "$TGZ" | awk '{print $1}')"
if [ -n "$NPM_SHA1" ] && [ "$NPM_SHA1" = "$TGZ_SHA1" ]; then
  echo "[*] tarball sha1 cocok"
else
  echo "[!] tarball sha1 mismatch: $TGZ_SHA1 (npm: $NPM_SHA1)"
  exit 1
fi

rm -rf "$WORK/tgz"
mkdir -p "$WORK/tgz"
tar xzf "$TGZ" -C "$WORK/tgz"
BIN_SRC="$WORK/tgz/package/bin/opencode"

if ! od -An -tx1 -N4 "$BIN_SRC" | grep -q '7f 45 4c 46'; then
  echo "[!] binary bukan ELF — salah unduh?"
  exit 1
fi

# ------------------------------------------------------------
# 3. Pasang binary + launcher
# ------------------------------------------------------------
cp "$BIN_SRC" "$BIN"
chmod 755 "$BIN"

# bersihkan instalasi musl (kalau ada) biar tidak tabrakan
if [ -d "$PREFIX/lib/opencode" ]; then
  echo "[*] hapus instalasi musl lama di $PREFIX/lib/opencode"
  rm -rf "$PREFIX/lib/opencode"
fi

cat > "$PREFIX/bin/opencode" <<EOF
#!/data/data/com.termux/files/usr/bin/sh
# Binary glibc opencode dijalankan lewat glibc-runner (grun), sama
# seperti claude-code-termux. termux-exec menaruh LD_PRELOAD bionic
# yang gagal di-relocate loader glibc — buang dulu sebelum exec.
unset LD_PRELOAD
unset LD_LIBRARY_PATH
exec grun $BIN "\$@"
EOF
chmod 755 "$PREFIX/bin/opencode"

# cek launcher terpasang dengan fix LD_PRELOAD
if ! grep -q 'unset LD_PRELOAD' "$PREFIX/bin/opencode"; then
  echo "[!] launcher gagal ditulis"
  exit 1
fi

# ------------------------------------------------------------
# 4. Patch keyboard HP: mouse capture opencode dimatikan (tap
#    layar = buka keyboard lagi), tombol KEYBOARD di extra keys
#    row Termux, dan auto-show keyboard tiap start (termux-api).
#    Semua idempotent — aman dijalankan berulang.
# ------------------------------------------------------------
PROPS="$HOME/.termux/termux.properties"
CONFIG="$HOME/.config/opencode/config.json"

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
EOF
  elif [ ! -s "$CONFIG" ]; then
    echo '{"enable_mouse_capture": false}' > "$CONFIG"
  fi
fi

mkdir -p "$(dirname "$PROPS")"
touch "$PROPS"
if grep -q '^extra-keys' "$PROPS" && ! grep '^extra-keys' "$PROPS" | grep -q 'KEYBOARD'; then
  sed -i 's/^\(extra-keys = \[[^]]*\)\]$/\1 KEYBOARD]/' "$PROPS"
elif ! grep -q '^extra-keys' "$PROPS"; then
  printf 'extra-keys = [ESC TAB CTRL ALT KEYBOARD]\n' >> "$PROPS"
fi

if ! command -v termux-keyboard-show >/dev/null 2>&1; then
  pkg install -y termux-api >/dev/null 2>&1 || echo "[!] termux-api gagal dipasang (offline?) — auto-show keyboard dilewati"
fi
if [ -f "$PREFIX/bin/opencode" ] && ! grep -q 'termux-keyboard-show' "$PREFIX/bin/opencode"; then
  sed -i '/^unset LD_LIBRARY_PATH/a command -v termux-keyboard-show >/dev/null 2>\&1 \&\& termux-keyboard-show' "$PREFIX/bin/opencode"
fi
command -v termux-reload-settings >/dev/null 2>&1 && termux-reload-settings
echo "[*] keyboard patch: mouse capture off + KEYBOARD key + auto-show"

# ------------------------------------------------------------
# 5. Verifikasi
# ------------------------------------------------------------
echo "[*] verifikasi:"
if "$PREFIX/bin/opencode" --version; then
  echo "[*] selesai. opencode $VERSION terpasang (glibc via grun)."
  echo "    Update: opencode upgrade"
  echo "    (baris verifikasi terakhir upgrade bisa melapor gagal padahal binary"
  echo "     sudah diganti — jalur curl mengeksekusi binary tanpa grun.)"
else
  echo "[!] gagal. Coba: BUN_JSC_useJIT=0 opencode"
fi

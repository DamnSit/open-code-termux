#!/data/data/com.termux/files/usr/bin/sh
# ============================================================
# uninstall-grun.sh — hapus opencode (glibc/grun)
# Konfigurasi opencode (~/.config/opencode, ~/.local/share/opencode)
# tidak disentuh.
# ============================================================
set -e

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN_DIR="$HOME/.opencode"

echo "[*] hapus launcher $PREFIX/bin/opencode"
rm -f "$PREFIX/bin/opencode"

echo "[*] hapus binary $BIN_DIR"
rm -rf "$BIN_DIR"

echo "[*] selesai."
echo ""
echo "    Catatan: glibc-repo + glibc-runner dibiarkan terpasang (dipakai juga"
echo "    oleh claude-code-termux). Hapus manual kalau tidak dibutuhkan lagi:"
echo "    pkg uninstall glibc-runner -y && pkg uninstall glibc-repo -y"
echo ""
echo "    Balik ke versi musl: sh install.sh"

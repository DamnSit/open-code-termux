#!/data/data/com.termux/files/usr/bin/sh
# ============================================================
# install.sh — opencode (musl aarch64) untuk Termux
# Dual mode:
#   Mode offline:  jalankan dari folder yang berisi opencode +
#                  ld-musl-aarch64.so.1 + libstdc++.so.6 + libgcc_s.so.1
#   Mode online:   unduh otomatis dari npm registry + Alpine CDN
# ============================================================
set -e

VERSION="1.18.14"
EXPECTED_SHA256="118df79cf90d3362efb574ab119059083c536b430e1dc8017552cc8a0b0257d7"

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$PREFIX/lib/opencode"
WORK="$HOME/.cache/opencode-termux"

ARCH="$(uname -m)"
[ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ] || { echo "[!] butuh aarch64, punya: $ARCH"; exit 1; }

mkdir -p "$DEST" "$PREFIX/bin" "$WORK"
echo "[*] opencode $VERSION (musl aarch64) -> $DEST"

# ------------------------------------------------------------
# 1. Ambil binary opencode: pakai file lokal kalau ada, kalau
#    tidak unduh dari npm registry
# ------------------------------------------------------------
if [ -f "$SRC/opencode" ]; then
  echo "[*] pakai opencode lokal"
  BIN_SRC="$SRC/opencode"
else
  TGZ="$WORK/opencode-$VERSION.tgz"
  if [ ! -f "$TGZ" ]; then
    echo "[*] unduh binary dari npm registry ..."
    curl -L --fail --retry 3 -o "$TGZ" \
      "https://registry.npmjs.org/opencode-linux-arm64-musl/-/opencode-linux-arm64-musl-$VERSION.tgz"
  fi
  rm -rf "$WORK/tgz"
  mkdir -p "$WORK/tgz"
  tar xzf "$TGZ" -C "$WORK/tgz"
  BIN_SRC="$WORK/tgz/package/bin/opencode"
fi

echo "[*] verifikasi sha256 ..."
ACTUAL="$(sha256sum "$BIN_SRC" | awk '{print $1}')"
if [ "$ACTUAL" != "$EXPECTED_SHA256" ]; then
  echo "[!] sha256 tidak cocok: $ACTUAL"
  echo "    expected: $EXPECTED_SHA256"
  echo "    (timpa dengan SKIP_CHECK=1 sh install.sh kalau kamu yakin)"
  [ -n "$SKIP_CHECK" ] || exit 1
fi

# ------------------------------------------------------------
# 2. Library pendukung (Alpine musl): loader, libc alias,
#    libstdc++, libgcc. Pakai lokal kalau ada.
# ------------------------------------------------------------
fetch_alpine() {
  PKG="$1"
  DEST_DIR="$2"
  APK="$WORK/$PKG.apk"
  if [ ! -f "$APK" ]; then
    URL=$(curl -s "https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/aarch64/" \
          | grep -o "$PKG-[0-9][^\"]*\.apk" | sort -V | tail -n 1)
    echo "[*] unduh $URL ..."
    curl -L --fail --retry 3 -o "$APK" "https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/aarch64/$URL"
  fi
  rm -rf "$DEST_DIR"
  mkdir -p "$DEST_DIR"
  tar xzf "$APK" -C "$DEST_DIR" 2>/dev/null || tar xzf "$APK" -C "$DEST_DIR" --no-same-owner
}

if [ -f "$SRC/ld-musl-aarch64.so.1" ] && [ -f "$SRC/libstdc++.so.6" ] && [ -f "$SRC/libgcc_s.so.1" ]; then
  echo "[*] library lokal"
  cp "$SRC/ld-musl-aarch64.so.1"   "$DEST/ld-musl-aarch64.so.1"
  cp "$SRC/libstdc++.so.6"         "$DEST/libstdc++.so.6"
  cp "$SRC/libgcc_s.so.1"          "$DEST/libgcc_s.so.1"
else
  fetch_alpine musl       "$WORK/musl"
  fetch_alpine libstdc++  "$WORK/stdcxx"
  fetch_alpine libgcc     "$WORK/gcc"

  cp "$(find "$WORK/musl"    -name 'ld-musl-aarch64.so.1' | head -n 1)" "$DEST/ld-musl-aarch64.so.1"
  cp "$(find "$WORK/stdcxx"  -name 'libstdc++.so.6*' -type f | head -n 1)" "$DEST/libstdc++.so.6"
  cp "$(find "$WORK/gcc"     -name 'libgcc_s.so.1' | head -n 1)"          "$DEST/libgcc_s.so.1"
fi

cp "$DEST/ld-musl-aarch64.so.1" "$DEST/libc.musl-aarch64.so.1"

# ------------------------------------------------------------
# 3. Pasang binary + launcher
# ------------------------------------------------------------
cp "$BIN_SRC" "$DEST/opencode"
chmod 755 "$DEST/opencode" "$DEST/ld-musl-aarch64.so.1"

cat > "$PREFIX/bin/opencode" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
# Binary musl opencode tidak bisa jalan langsung di Termux (bionic libc).
# Loader musl dipanggil langsung dengan --library-path, tanpa patchelf.
exec /data/data/com.termux/files/usr/lib/opencode/ld-musl-aarch64.so.1 \
  --library-path /data/data/com.termux/files/usr/lib/opencode \
  /data/data/com.termux/files/usr/lib/opencode/opencode "$@"
EOF
chmod 755 "$PREFIX/bin/opencode"

# ------------------------------------------------------------
# 4. Verifikasi
# ------------------------------------------------------------
echo "[*] verifikasi:"
if "$PREFIX/bin/opencode" --version; then
  echo "[*] selesai. Jalankan: opencode"
else
  echo "[!] gagal. Coba: BUN_JSC_useJIT=0 opencode"
fi

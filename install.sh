#!/data/data/com.termux/files/usr/bin/sh
# ============================================================
# install.sh — opencode (musl aarch64) untuk Termux
# Dual mode:
#   Mode offline:  jalankan dari folder yang berisi opencode +
#                  ld-musl-aarch64.so.1 + libstdc++.so.6 + libgcc_s.so.1
#   Mode online:   unduh otomatis dari npm registry + Alpine CDN
# ============================================================
set -e

EXPECTED_SHA256="118df79cf90d3362efb574ab119059083c536b430e1dc8017552cc8a0b0257d7"
INSTALLER_REV="4"

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$PREFIX/lib/opencode"
WORK="$HOME/.cache/opencode-termux"

ARCH="$(uname -m)"
[ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ] || { echo "[!] butuh aarch64, punya: $ARCH"; exit 1; }

mkdir -p "$DEST" "$PREFIX/bin" "$WORK"

# ------------------------------------------------------------
# 0. Versi: auto-detect terbaru dari npm, atau pin manual
#    dengan: VERSION=1.18.14 sh install.sh
# ------------------------------------------------------------
if [ -z "${VERSION:-}" ]; then
  VERSION="$(curl -s --fail https://registry.npmjs.org/opencode-linux-arm64-musl/latest \
             | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')"
  if [ -z "$VERSION" ]; then
    echo "[!] gagal deteksi versi terbaru. Pin manual: VERSION=1.18.14 sh install.sh"
    exit 1
  fi
fi
echo "[*] installer rev $INSTALLER_REV — opencode $VERSION (musl aarch64) -> $DEST"

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
    echo "[*] unduh binary $VERSION dari npm registry ..."
    curl -L --fail --retry 3 -o "$TGZ" \
      "https://registry.npmjs.org/opencode-linux-arm64-musl/-/opencode-linux-arm64-musl-$VERSION.tgz"
  fi

  # versi non-pin: verifikasi tarball terhadap shasum npm
  if [ "$VERSION" != "1.18.14" ]; then
    NPM_SHA1="$(curl -s --fail "https://registry.npmjs.org/opencode-linux-arm64-musl/$VERSION" \
                | sed -n 's/.*"shasum":"\([^"]*\)".*/\1/p')"
    TGZ_SHA1="$(sha1sum "$TGZ" | awk '{print $1}')"
    if [ "$NPM_SHA1" = "$TGZ_SHA1" ]; then
      echo "[*] tarball sha1 cocok"
    else
      echo "[!] tarball sha1 mismatch: $TGZ_SHA1 (npm: $NPM_SHA1)"
      exit 1
    fi
  fi

  rm -rf "$WORK/tgz"
  mkdir -p "$WORK/tgz"
  tar xzf "$TGZ" -C "$WORK/tgz"
  BIN_SRC="$WORK/tgz/package/bin/opencode"
fi

# verifikasi: sha256 (hanya untuk 1.18.14 yang diuji manual) + cek ELF aarch64
if [ "$VERSION" = "1.18.14" ]; then
  echo "[*] verifikasi sha256 ..."
  ACTUAL="$(sha256sum "$BIN_SRC" | awk '{print $1}')"
  if [ "$ACTUAL" != "$EXPECTED_SHA256" ]; then
    echo "[!] sha256 tidak cocok: $ACTUAL"
    echo "    expected: $EXPECTED_SHA256"
    echo "    (timpa dengan SKIP_CHECK=1 sh install.sh kalau kamu yakin)"
    [ -n "$SKIP_CHECK" ] || exit 1
  fi
fi
if ! od -An -tx1 -N4 "$BIN_SRC" | grep -q '7f 45 4c 46'; then
  echo "[!] binary bukan ELF — salah unduh?"
  exit 1
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
# termux-exec menaruh LD_PRELOAD bionic yang gagal di-relocate loader
# musl (__errno, __register_atfork, ...) — buang dulu sebelum exec.
unset LD_PRELOAD
unset LD_LIBRARY_PATH
exec /data/data/com.termux/files/usr/lib/opencode/ld-musl-aarch64.so.1 \
  --library-path /data/data/com.termux/files/usr/lib/opencode \
  /data/data/com.termux/files/usr/lib/opencode/opencode "$@"
EOF
chmod 755 "$PREFIX/bin/opencode"

# cek launcher benar-benar terpasang dengan fix LD_PRELOAD
if ! grep -q 'unset LD_PRELOAD' "$PREFIX/bin/opencode"; then
  echo "[!] launcher gagal ditulis (versi install.sh lama?) — cari 'rev 4' di output"
  exit 1
fi

# ------------------------------------------------------------
# 4. Verifikasi
# ------------------------------------------------------------
echo "[*] verifikasi:"
if "$PREFIX/bin/opencode" --version; then
  echo "[*] selesai. opencode $VERSION terpasang. Jalankan: opencode"
  echo "    (update berikutnya cukup: sh install.sh — tanpa 'opencode upgrade')"
else
  echo "[!] gagal. Coba: BUN_JSC_useJIT=0 opencode"
fi

# open-code-termux

**opencode** — AI coding agent CLI — di **Termux** (Android, aarch64/arm64).

Binary resmi `opencode-linux-arm64-musl` di-link ke `/lib/ld-musl-aarch64.so.1`
yang tidak ada di Termux (Termux pakai bionic libc). Repo ini mengemas ulang
binary tersebut dengan **loader musl + library pendukung dari Alpine**, dan
memanggil loader secara langsung dengan `--library-path` — **tanpa patchelf,
tanpa root**.

Ada **dua metode instalasi**:

- **Metode A (musl, default)** — self-contained, tanpa paket tambahan.
  Update: `sh install.sh`.
- **Metode B (glibc via glibc-runner)** — cara yang sama dengan
  [claude-code-termux](https://github.com/DamnSit/claude-code-termux).
  Update: `opencode upgrade` berfungsi penuh.

## Persyaratan

- Ponsel **aarch64 / arm64** (hampir semua HP modern). Cek: `uname -m`
- Termux dari F-Droid / GitHub releases (versi terbaru)
- Koneksi internet untuk metode online (~65 MB unduhan)

## Instalasi Metode A — Musl (online, default)

```bash
pkg update
pkg install -y curl
curl -L -o install.sh https://raw.githubusercontent.com/DamnSit/open-code-termux/main/install.sh
sh install.sh
```

Atau lewat git:

```bash
pkg update
pkg install -y curl git
git clone https://github.com/DamnSit/open-code-termux.git
cd open-code-termux
sh install.sh
```

Script akan mengunduh:
- `opencode` 1.18.14 (musl aarch64) dari npm registry, diverifikasi dengan SHA-256
- `ld-musl-aarch64.so.1` + `libstdc++.so.6` + `libgcc_s.so.1` dari Alpine CDN

Lalu memasang semuanya ke `$PREFIX/lib/opencode/` dan membuat launcher
`$PREFIX/bin/opencode`.

## Instalasi Metode B — Glibc via glibc-runner (opsional)

Cara yang sama dengan claude-code-termux: binary resmi build **glibc**
dijalankan dengan **`grun`** (glibc-runner, `$PREFIX/glibc`).

```bash
pkg update
pkg install -y curl
curl -L -o install-grun.sh https://raw.githubusercontent.com/DamnSit/open-code-termux/main/install-grun.sh
sh install-grun.sh
```

Script akan:
- memasang `glibc-repo` + `glibc-runner` lewat `pkg` (kalau belum ada)
- mengunduh `opencode-linux-arm64` (build glibc) dari npm, diverifikasi sha1
- memasang binary ke `~/.opencode/bin/opencode` + launcher `$PREFIX/bin/opencode`
- menghapus instalasi musl lama otomatis

Pilih metode ini kalau ingin **`opencode upgrade`** berfungsi penuh.
Trade-off: paket glibc tambahan (±300 MB).

## Instalasi (Offline / Tanpa Internet)

1. Di PC, buat paket offline: salin `opencode`, `ld-musl-aarch64.so.1`,
   `libstdc++.so.6`, `libgcc_s.so.1`, dan `install.sh` ke satu folder.
   (Folder `bundle/` + binary dari npm tarball, atau paket zip yang sudah
   dirakit di PC.)
2. Transfer ke HP (USB / Google Drive / `adb push`).
3. Di Termux:

```bash
pkg install -y curl
cd ~
unzip opencode-termux.zip
cd opencode-termux
sh install.sh
```

Script otomatis mendeteksi file lokal dan melewati unduhan.

## Cara Pakai

```bash
opencode
```

- Login pertama kali: pilih provider (Anthropic, OpenAI, dll.) dan masukkan
  API key, atau pakai mode lokal.
- Semua konfigurasi tersimpan di `~/.local/share/opencode/` dan
  `~/.config/opencode/`.

## Update

**Metode A (musl):**

```bash
sh install.sh
```

Installer rev 4 otomatis mendeteksi versi terbaru dari npm dan menginstalnya.

> **PENTING (musl):** jangan pakai `opencode upgrade` di instalasi musl —
> jalur `curl`-nya mengunduh build glibc (`opencode-linux-arm64`) yang tidak
> bisa berjalan. `opencode update` juga bukan command yang valid — opencode
> memperlakukan argumen itu sebagai path direktori. Satu-satunya jalur update
> yang aman: `sh install.sh` (atau pin versi manual:
> `VERSION=1.18.14 sh install.sh`).

**Metode B (glibc/grun):**

```bash
opencode upgrade
```

Karena binary berada di `~/.opencode/bin/opencode`, opencode mengenali
instalasinya sebagai metode `curl` dan mengganti binary-nya sendiri.
Baris verifikasi terakhir upgrade bisa melapor gagal (opencode mengeksekusi
binary tanpa `grun`) padahal binary sudah terganti — cek `opencode --version`.
Alternatif: `sh install-grun.sh` (auto-detect versi terbaru dari npm).

## Troubleshooting

| Gejala | Solusi |
|---|---|
| `--version` jalan tapi hang saat start | `BUN_JSC_useJIT=0 opencode` (JIT dibatasi SELinux Android) |
| DNS gagal / `ETIMEOUT` | Kemungkinan kecil: musl me-parse `resolv.conf` sendiri, tidak lewat NSS glibc. Kalau terjadi, cek `cat /etc/resolv.conf` |
| `sha256 mismatch` | Download korup. Hapus `~/.cache/opencode-termux` lalu jalankan ulang |
| `not found: libstdc++.so.6` | Instalasi lama. Hapus `$PREFIX/lib/opencode` lalu `sh install.sh` lagi |
| `Error relocating ... libtermux-exec-ld-preload.so: symbol not found` | `LD_PRELOAD` bionic dari `termux-exec` mengganggu loader musl. Update launcher: jalankan `git pull` lalu `sh install.sh` lagi (versi baru otomatis mengosongkan `LD_PRELOAD`) |
| Output installer tidak menampilkan `rev 3` | Installer yang diunduh masih versi lama (cache CDN raw GitHub). Unduh ulang atau pakai URL commit: `curl -L -o install.sh https://raw.githubusercontent.com/DamnSit/open-code-termux/main/install.sh?x=$(date +%s)` |
| Layar TUI berantakan | `export TERM=xterm-256color` sebelum `opencode` |
| Metode B: `command not found: grun` | `pkg install glibc-repo -y && pkg update && pkg install glibc-runner -y` |
| Metode B: `opencode upgrade` melapor gagal tapi versi tidak berubah | Jalankan ulang `opencode upgrade`, atau `sh install-grun.sh` (auto-detect npm) |
| Metode B: binary glibc gagal jalan langsung | Itu normal — binary glibc butuh loader glibc (`$PREFIX/glibc`); selalu jalankan lewat launcher `opencode` |

## Cara Kerja

```
opencode (ELF aarch64, musl)
  interp: /lib/ld-musl-aarch64.so.1        <- tidak ada di Termux
  NEEDED: libstdc++.so.6, libc.musl-aarch64.so.1, libgcc_s.so.1

Solusi:
  ld-musl-aarch64.so.1 --library-path $PREFIX/lib/opencode \
    $PREFIX/lib/opencode/opencode "$@"
```

- Loader musl dipanggil langsung sebagai executable — tidak perlu menulis ulang
  `PT_INTERP` (patchelf opsional, hanya untuk meluncurkan tanpa awalan loader).
- `libc.musl-aarch64.so.1` adalah loader itu sendiri dengan nama libc-nya.
- Bonus: `getaddrinfo` musl me-parse `resolv.conf` sendiri, jadi bug DNS
  yang pernah memakan claude-code di Termux umumnya tidak terjadi di sini.

## File

| File | Keterangan |
|---|---|
| `install.sh` | Installer Metode A — musl, dual-mode (online/offline), verifikasi SHA-256 |
| `install-grun.sh` | Installer Metode B — binary glibc resmi + glibc-runner (cara claude-code-termux), `opencode upgrade` berfungsi |
| `uninstall-grun.sh` | Menghapus launcher + binary glibc/grun |
| `launcher` | Wrapper yang memanggil loader musl (dipakai instalasi offline) |
| `opencode` | Binary 1.18.14 musl aarch64 — TIDAK di-repo (file > 100MB), diunduh script |

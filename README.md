# open-code-termux

**opencode** — AI coding agent CLI — on **Termux** (Android, aarch64/arm64).

The official `opencode-linux-arm64-musl` binary is linked against
`/lib/ld-musl-aarch64.so.1`, which does not exist on Termux (Termux uses
bionic libc). This repo repackages the binary with the **musl loader +
supporting libraries from Alpine** and invokes the loader directly with
`--library-path` — **no patchelf, no root**.

There are **two installation methods**:

- **Method A (musl, default)** — self-contained, no extra packages.
  Update: `sh install.sh`.
- **Method B (glibc via glibc-runner)** — the same approach as
  [claude-code-termux](https://github.com/DamnSit/claude-code-termux).
  Update: full `opencode upgrade` support.

## Requirements

- **aarch64 / arm64** device (almost all modern phones). Check: `uname -m`
- Termux from F-Droid / GitHub releases (latest version)
- Internet connection for the online method (~65 MB download)

## Installation Method A — Musl (online, default)

```bash
pkg update
pkg install -y curl
curl -L -o install.sh https://raw.githubusercontent.com/DamnSit/open-code-termux/main/install.sh
sh install.sh
```

Or via git:

```bash
pkg update
pkg install -y curl git
git clone https://github.com/DamnSit/open-code-termux.git
cd open-code-termux
sh install.sh
```

The script downloads:
- `opencode` 1.18.14 (musl aarch64) from the npm registry, verified with SHA-256
- `ld-musl-aarch64.so.1` + `libstdc++.so.6` + `libgcc_s.so.1` from the Alpine CDN

Then installs everything into `$PREFIX/lib/opencode/`, creates the
`$PREFIX/bin/opencode` launcher, and applies the **keyboard patch**
(mouse capture off so taps reopen the phone keyboard, KEYBOARD extra key,
auto-show via termux-api).

## Installation Method B — Glibc via glibc-runner (optional)

The same approach as claude-code-termux: the official **glibc** build is run
with **`grun`** (glibc-runner, `$PREFIX/glibc`).

```bash
pkg update
pkg install -y curl
curl -L -o install-grun.sh https://raw.githubusercontent.com/DamnSit/open-code-termux/main/install-grun.sh
sh install-grun.sh
```

The script will:
- install `glibc-repo` + `glibc-runner` via `pkg` (if not already present)
- download `opencode-linux-arm64` (glibc build) from npm, verified against the registry sha1
- install the binary to `~/.opencode/bin/opencode` + launcher `$PREFIX/bin/opencode`
- automatically remove any previous musl install
- apply the **keyboard patch** (mouse capture off, KEYBOARD extra key, auto-show via termux-api)

Pick this method if you want **`opencode upgrade`** to work natively.
Trade-off: additional glibc packages (±300 MB).

## Installation (Offline / No Internet)

1. On a PC, build the offline bundle: copy `opencode`, `ld-musl-aarch64.so.1`,
   `libstdc++.so.6`, `libgcc_s.so.1`, and `install.sh` into one folder.
   (The `bundle/` folder plus the binary from the npm tarball, or the zip
   already assembled on the PC.)
2. Transfer to the phone (USB / Google Drive / `adb push`).
3. In Termux:

```bash
pkg install -y curl
cd ~
unzip opencode-termux.zip
cd opencode-termux
sh install.sh
```

The script automatically detects the local files and skips the downloads.

## Usage

```bash
opencode
```

- First login: pick a provider (Anthropic, OpenAI, etc.) and enter your API
  key, or use local mode.
- All configuration is stored in `~/.local/share/opencode/` and
  `~/.config/opencode/`.

## Update

**Method A (musl):**

```bash
sh install.sh
```

Installer rev 5 automatically detects the latest version from npm, installs it,
and applies the keyboard patch.

> **IMPORTANT (musl):** do NOT use `opencode upgrade` on a musl install —
> its `curl` path downloads the glibc build (`opencode-linux-arm64`), which
> cannot run. `opencode update` is also not a valid command — opencode treats
> the argument as a directory path. The only safe update path: `sh install.sh`
> (or pin the version manually: `VERSION=1.18.14 sh install.sh`).

**Method B (glibc/grun):**

```bash
opencode upgrade
```

Because the binary lives at `~/.opencode/bin/opencode`, opencode recognizes
the install as a `curl`-method install and replaces its own binary.
The final verification step of the upgrade may report failure (opencode
executes the binary without `grun`) even though the binary was already
replaced — check with `opencode --version`.
Alternative: `sh install-grun.sh` (auto-detects the latest version from npm).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `--version` works but hangs on start | `BUN_JSC_useJIT=0 opencode` (JIT is restricted by Android SELinux) |
| DNS failures / `ETIMEOUT` | Unlikely: musl parses `resolv.conf` itself, not via glibc NSS. If it happens, check `cat /etc/resolv.conf` |
| `sha256 mismatch` | Corrupted download. Delete `~/.cache/opencode-termux` and re-run |
| `not found: libstdc++.so.6` | Old install. Delete `$PREFIX/lib/opencode` and run `sh install.sh` again |
| `Error relocating ... libtermux-exec-ld-preload.so: symbol not found` | The bionic `LD_PRELOAD` from `termux-exec` interferes with the musl loader. Update the launcher: run `git pull` then `sh install.sh` again (new versions clear `LD_PRELOAD` automatically) |
| Installer output does not show `rev 3` | Downloaded installer is an old cached version (GitHub raw CDN cache). Re-download or use a commit URL: `curl -L -o install.sh https://raw.githubusercontent.com/DamnSit/open-code-termux/main/install.sh?x=$(date +%s)` |
| Messy TUI screen | `export TERM=xterm-256color` before `opencode` |
| Method B: `command not found: grun` | `pkg install glibc-repo -y && pkg update && pkg install glibc-runner -y` |
| Method B: `opencode upgrade` reports failure but version stays the same | Run `opencode upgrade` again, or `sh install-grun.sh` (npm auto-detect) |
| Method B: glibc binary fails when run directly | Normal — the glibc binary needs the glibc loader (`$PREFIX/glibc`); always run via the `opencode` launcher |
| Phone keyboard does not open when tapping the screen in opencode | The TUI captures taps as mouse events. Reinstall to get the patch: `sh install.sh` (rev 5+ includes it), or for existing installs: `sh patch-keyboard.sh` (disables mouse capture, adds the KEYBOARD extra key, auto-shows the keyboard via termux-api) |

## How It Works

```
opencode (ELF aarch64, musl)
  interp: /lib/ld-musl-aarch64.so.1        <- not present on Termux
  NEEDED: libstdc++.so.6, libc.musl-aarch64.so.1, libgcc_s.so.1

Solution:
  ld-musl-aarch64.so.1 --library-path $PREFIX/lib/opencode \
    $PREFIX/lib/opencode/opencode "$@"
```

- The musl loader is invoked directly as an executable — no need to rewrite
  `PT_INTERP` (patchelf is optional, only to launch without the loader prefix).
- `libc.musl-aarch64.so.1` is the loader itself under its libc name.
- Bonus: musl `getaddrinfo` parses `resolv.conf` on its own, so the DNS bug
  that once hit claude-code on Termux generally does not happen here.

## Files

| File | Description |
|---|---|
| `install.sh` | Method A installer — musl, dual-mode (online/offline), SHA-256 verification |
| `install-grun.sh` | Method B installer — official glibc build + glibc-runner (claude-code-termux style), full `opencode upgrade` support |
| `uninstall-grun.sh` | Removes the launcher + glibc/grun binary |
| `patch-keyboard.sh` | Fixes the on-screen keyboard not opening in opencode (mouse capture off, KEYBOARD extra key, auto-show via termux-api) |
| `launcher` | Wrapper that invokes the musl loader (used by offline installs) |
| `opencode` | 1.18.14 musl aarch64 binary — NOT in the repo (>100MB file, downloaded by the script) |

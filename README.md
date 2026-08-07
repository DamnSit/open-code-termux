# open-code-termux

**opencode** — AI coding agent CLI — on **Termux** (Android, aarch64/arm64).

The official **glibc** build (`opencode-linux-arm64`) is run with **`grun`**
(glibc-runner, `$PREFIX/glibc`) — the same approach as
[claude-code-termux](https://github.com/DamnSit/claude-code-termux).
The glibc-runner handles the loader environment, so the binary runs natively
and **`opencode upgrade` works** out of the box.

## Requirements

- **aarch64 / arm64** device (almost all modern phones). Check: `uname -m`
- Termux from F-Droid / GitHub releases (latest version)
- Internet connection (~300 MB glibc packages + ~80 MB binary)

## Installation

```bash
pkg update
pkg install -y curl
curl -L -o install-grun.sh https://raw.githubusercontent.com/DamnSit/open-code-termux/main/install-grun.sh
sh install-grun.sh
```

Or via git:

```bash
pkg update
pkg install -y curl git
git clone https://github.com/DamnSit/open-code-termux.git
cd open-code-termux
sh install-grun.sh
```

The script will:
- install `glibc-repo` + `glibc-runner` via `pkg` (if not already present)
- download `opencode-linux-arm64` (glibc build) from npm, verified against the registry sha1
- install the binary to `~/.opencode/bin/opencode` + launcher `$PREFIX/bin/opencode`
- apply the **keyboard patch** (KEYBOARD extra key + auto-show via termux-api;
  TUI mouse capture stays **on** so the clickable buttons keep working)
- fix `/etc/resolv.conf` for DNS if it is missing or broken

## Usage

```bash
opencode
```

- First login: pick a provider (Anthropic, OpenAI, etc.) and enter your API
  key, or use local mode.
- All configuration is stored in `~/.local/share/opencode/` and
  `~/.config/opencode/`.

## Update

```bash
opencode upgrade
```

Because the binary lives at `~/.opencode/bin/opencode`, opencode recognizes
the install as a `curl`-method install and replaces its own binary.
The final verification step of the upgrade may report failure (opencode
executes the binary without `grun`) even though the binary was already
replaced — check with `opencode --version`.
Alternative: `sh install-grun.sh` (auto-detects the latest version from npm).

> `opencode update` is not a valid command — opencode treats the argument as
> a directory path.

## Uninstall

```bash
curl -L -o uninstall-grun.sh https://raw.githubusercontent.com/DamnSit/open-code-termux/main/uninstall-grun.sh
sh uninstall-grun.sh
```

Removes the launcher and the binary. The glibc packages stay (claude-code-termux
uses them too) and your opencode config is untouched.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `command not found: grun` | `pkg install glibc-repo -y && pkg update && pkg install glibc-runner -y` |
| `--version` works but hangs on start | `BUN_JSC_useJIT=0 opencode` (JIT is restricted by Android SELinux) |
| DNS failures / `ETIMEOUT` / `Cannot connect to API` | opencode parses `/etc/resolv.conf` itself, not the Android resolver. If the file is missing or only lists localhost, all API connections fail. Fix: `printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > $PREFIX/etc/resolv.conf` (install-grun.sh rev 4+ does this automatically) |
| `opencode upgrade` reports failure but version stays the same | Run `opencode upgrade` again, or `sh install-grun.sh` (npm auto-detect) |
| glibc binary fails when run directly | Normal — the glibc binary needs the glibc loader (`$PREFIX/glibc`); always run via the `opencode` launcher |
| `sha1 mismatch` | Corrupted download. Delete `~/.cache/opencode-grun` and re-run |
| Phone keyboard does not open when tapping the screen in opencode | Expected — with mouse capture ON (default) taps are clicks on TUI buttons, like on Windows. Type using the **KEYBOARD** extra key (added by the patch), or hold it to auto-show at launch |
| TUI buttons are not clickable anymore (patch rev < 5) | The old patch wrote `"mouse": false` to `~/.config/opencode/tui.json` which kills the clickable buttons. Fix: `rm -f ~/.config/opencode/tui.json`, or reinstall: `sh install-grun.sh` (rev 5+ removes it automatically) |
| Messy TUI screen | `export TERM=xterm-256color` before `opencode` |
| Installer output does not show `rev 5` | Downloaded installer is an old cached version (GitHub raw CDN cache). Re-download or use a commit URL: `curl -L -o install-grun.sh https://raw.githubusercontent.com/DamnSit/open-code-termux/main/install-grun.sh?x=$(date +%s)` |

## How It Works

```
opencode (ELF aarch64, glibc)
  interp: /lib64/ld-linux-aarch64.so.1     <- not loadable by bionic (Termux libc)

Solution:
  $PREFIX/bin/opencode  ->  grun ~/.opencode/bin/opencode
                            (glibc-runner sets up $PREFIX/glibc loader + libs)
```

- `glibc-runner` provides a full glibc environment (`$PREFIX/glibc`) with the
  loader, libc, libstdc++ and libgcc — no patchelf, no root.
- The launcher clears `LD_PRELOAD` (bionic `termux-exec` preload breaks the
  glibc loader) and runs the binary through `grun`.
- Because the binary path matches opencode's own install layout
  (`~/.opencode/bin/opencode`), `opencode upgrade` replaces it natively.

## Files

| File | Description |
|---|---|
| `install-grun.sh` | Installer — official glibc build + glibc-runner (claude-code-termux style), full `opencode upgrade` support |
| `uninstall-grun.sh` | Removes the launcher + glibc/grun binary |
| `patch-keyboard.sh` | On-screen keyboard helper — KEYBOARD extra key + auto-show via termux-api, keeps TUI mouse capture on so buttons stay clickable |
| `opencode` | Binary — NOT in the repo (downloaded by the script from npm) |

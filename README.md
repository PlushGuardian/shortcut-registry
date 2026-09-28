# shortcut-registry

`sc` — a tiny bash shortcut registry. Name a shell command once, run it with `sc NAME [args...]`.

## Quickstart

```bash
make install
source ~/.bashrc
sc add hello "Say hi" :: 'echo hi-{1}'
sc hello world   # → hi-world
sc list
```

## Layout

Repo:

```
src/sc.sh    # canonical code (sourced, not executed)
Makefile     # install / uninstall / lint / test
```

Installed (`$SHORTCUT_REGISTRY_PATH`, default `~/.shortcut-registry/`):

```
~/.shortcut-registry/
├── sc.sh       # code (installed copy of src/sc.sh)
└── shortcuts   # data (TSV: name<TAB>description<TAB>command)
```

Only the base directory is configurable via `SHORTCUT_REGISTRY_PATH`. The `sc.sh` / `shortcuts` filenames are hardcoded from it.

## Install

```bash
make install
source ~/.bashrc
```

This:

1. Copies `src/sc.sh` → `~/.shortcut-registry/sc.sh`.
2. Appends an idempotent hook block to `~/.bashrc` (with a dated `~/.bashrc.bak.YYYYMMDD-HHMMSS` backup first). The hook references only the folder — every `*.sh` in the registry dir is sourced, so the data file is never executed:

```bash
export SHORTCUT_REGISTRY_PATH="${SHORTCUT_REGISTRY_PATH:-$HOME/.shortcut-registry}"
for _sc_src in "$SHORTCUT_REGISTRY_PATH"/*.sh; do
  [[ -f "$_sc_src" ]] && source "$_sc_src"
done
unset _sc_src
```

Custom locations:

```bash
make install REGISTRY_DIR=~/my-reg BASHRC=~/.bashrc
```

## Usage

```bash
sc add NAME "DESCRIPTION" :: 'COMMAND'   # quote the command when adding
sc NAME [args...]                        # run a shortcut
sc list                                  # list names + descriptions
sc help                                  # help + current commands
sc rm NAME [NAME ...]                    # remove one or more shortcuts
```

Commands support:

- Positional placeholders `{1}` … `{9}` for whole arguments; extra args are appended:
  ```bash
  sc add ytdl "Download YT" :: 'yt-dlp --cookies-from-browser firefox {1}'
  sc ytdl <url>
  ```
- Runtime shell-variable expansion (single-quote at add time):
  ```bash
  sc add m3 "Extract mp3" :: 'yt-dlp -x --audio-format mp3 "$FMT" {1}'
  FMT=bestaudio sc m3 <url>
  ```

Tab completion covers subcommands and shortcut names (bash `complete` only).

## Uninstall

```bash
make uninstall            # removes code + bashrc hook, keeps data
make uninstall PURGE=1    # also removes the shortcuts data file
```

## Development

Requirements: GNU make, bash. `shellcheck` is optional.

```bash
make lint   # bash -n (+ shellcheck if available)
make test   # clean-shell smoke test: add / list / run / rm / help
```

## Roadmap (not implemented yet)

- `sc prev` command
- Import shortcuts from backup
- `~/.bash_profile` / zsh support

# ubuntu-dotfiles

Dotfiles for my Ubuntu work laptop.
Ported from [air-dotfiles](https://github.com/eesoymilk/air-dotfiles) (macOS), which remains the upstream for anything in the shared terminal layer.

Sibling repos: `air-dotfiles` (macOS), `arch-dotfiles-btw` (Arch + Hyprland).

## Install

This repo is private, so install and authenticate `gh` first:

```bash
sudo apt update && sudo apt install -y git gh
gh auth login   # GitHub.com -> HTTPS -> authenticate git -> browser
```

Then clone to exactly `~/ubuntu-dotfiles` (the path is baked into `tmux-sessionizer`
and the yazi `g .` keybind):

```bash
gh repo clone eesoymilk/ubuntu-dotfiles ~/ubuntu-dotfiles
cd ~/ubuntu-dotfiles
./bootstrap.sh
```

`bootstrap.sh` is idempotent, so re-running it to pick up a new tool is safe.
It needs `sudo`.

No single tool can abort the run.
Each section is a step, and a step that fails is recorded while the rest still install, so one unreachable mirror costs you that tool rather than the whole machine.
The summary at the end lists every step as `ok` or `FAILED` and the script exits non-zero if anything failed.
Re-running retries only what is missing.


Because `gh auth login` has to happen before cloning a private repo, `~/.config/gh/config.yml` already exists by the time stow runs.
That is a real conflict and bootstrap handles it: conflicting files are moved to `~/dotfiles-backup-<timestamp>/` before stowing.
Your credentials in `hosts.yml` are gitignored and never touched.

Then open a new terminal and:

1. Wait a few seconds on first launch while zinit installs the zsh plugins.
2. Start `tmux` once so TPM clones itself and installs plugins.
3. `nvm install --lts`
4. Set your terminal font to **JetBrainsMono Nerd Font**.

## What's here

| Path | Notes |
| --- | --- |
| `.zshrc` | zinit, fzf-tab, zoxide, oh-my-posh, aliases |
| `.config/nvim/` | lazy.nvim setup, carried verbatim from macOS |
| `.config/tmux/` | Catppuccin, `Ctrl+a` prefix, TPM, sessionizer |
| `.config/yazi/` | file manager, `y` wrapper in `.zshrc` |
| `.config/ohmyposh/` | `zen.toml` prompt |
| `.config/git/`, `.config/gh/` | global gitignore, gh settings (no credentials) |
| `.config/herdr/` | terminal workspace manager for agents |
| `.config/ghostty/` | terminal config; Ghostty is installed by bootstrap |
| `.claude/agents/`, `AGENTS.md` | agent config, symlinked to `~/.claude/CLAUDE.md` |
| `.local/bin/tmux-sessionizer` | `prefix + f` popup, `tms` alias |

Not ported from the macOS repo: `aerospace/` (macOS-only), `btop/` and `htop/` (auto-generated stock defaults).

## Install methods

Every tool is installed the way its own documentation prescribes, rather than by a hand-rolled fetch.
Upstream changes asset names and layouts, and the documented path is what keeps `bootstrap.sh` working over time.

| Tool | Method |
| --- | --- |
| zsh, stow, tmux, git, ripgrep, jq, wl-clipboard | Ubuntu apt |
| fd, bat | Ubuntu apt as `fdfind` / `batcat`, symlinked to upstream names |
| neovim | official release tarball under `/opt`, with a stable `/opt/nvim` symlink |
| eza | official apt repository (`deb.gierens.de`) |
| yazi | official apt repository (`yazi-rs.github.io/builds`); plugins via `ya pkg install` |
| fzf | official git clone + `~/.fzf/install --no-update-rc` |
| zoxide, oh-my-posh, lazydocker, nvm | official upstream install scripts |
| lazygit | apt where packaged, else the official release recipe |
| git-delta | official `.deb` from the releases page |
| gh | GitHub's official apt repository |
| ghostty | Ubuntu archive from 26.04, else the community `.deb` upstream documents |

Both `amd64` and `arm64` are handled; the script resolves each project's asset naming from `uname -m` and exits early on anything else.

Two installers need guarding because `~/.zshrc` is a symlink into this repo: `fzf` gets `--no-update-rc` and `nvm` gets `PROFILE=/dev/null`.
Without those, each would append its own setup lines into the dotfiles and propagate to the other machines.

## Differences from the macOS repo

These are the only real deltas.
Keep them in mind when syncing a change between the two repos.

| Item | macOS | Ubuntu |
| --- | --- | --- |
| Homebrew `shellenv` | line 1 of `.zshrc` | removed |
| `PNPM_HOME` | `~/Library/pnpm` | `~/.local/share/pnpm` |
| micromamba block | present, hardcoded paths | removed (personal-project scoped) |
| oh-my-posh guard | skipped under Apple Terminal | unconditional |
| tmux clipboard | `pbcopy` | `wl-copy` |
| sessionizer repo path | `~/air-dotfiles` | `~/ubuntu-dotfiles` |
| Window manager | AeroSpace | none, stock GNOME |

### Ubuntu binary-name gotcha

Ubuntu ships `fd` as `fdfind` and `bat` as `batcat` to avoid package collisions.
The `cat='bat'` alias and the `fd` call inside `tmux-sessionizer` both expect the upstream names, so `bootstrap.sh` symlinks them into `~/.local/bin`.
If `cat` or `prefix + f` misbehaves, check those symlinks first.

### Ghostty

Ghostty reached the Ubuntu archive in 26.04.
On 24.04 there is no archive package, and upstream's own install docs point at the community `.deb` from [ghostty-ubuntu](https://github.com/mkasberg/ghostty-ubuntu) as the only prebuilt option for older releases.
`bootstrap.sh` follows that split: apt where the archive has it, the community installer otherwise.

The community `.deb` is installed directly rather than through an apt source, so it does not upgrade with `apt upgrade`.
Re-run `bootstrap.sh`'s installer, or the upstream one-liner, to move to a newer Ghostty.


## Uninstall

```bash
cd ~/ubuntu-dotfiles && stow -t ~ -D .
```

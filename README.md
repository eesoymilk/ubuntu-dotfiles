# ubuntu-dotfiles

Dotfiles for my Ubuntu work laptop.
Ported from [air-dotfiles](https://github.com/eesoymilk/air-dotfiles) (macOS), which remains the upstream for anything in the shared terminal layer.

Sibling repos: `air-dotfiles` (macOS), `arch-dotfiles-btw` (Arch + Hyprland).

## Install

```bash
git clone https://github.com/eesoymilk/ubuntu-dotfiles.git ~/ubuntu-dotfiles
cd ~/ubuntu-dotfiles
./bootstrap.sh
```

`bootstrap.sh` is idempotent, so re-running it to pick up a new tool is safe.
It needs `sudo`.

Because `gh auth login` has to happen before cloning a private repo, `~/.config/gh/config.yml` already exists by the time stow runs.
That is a real conflict and bootstrap handles it: conflicting files are moved to `~/dotfiles-backup-<timestamp>/` before stowing.
Your credentials in `hosts.yml` are gitignored and never touched.

Then open a new terminal and:

1. Wait a few seconds on first launch while zinit installs the zsh plugins.
2. Start `tmux` once so TPM clones itself and installs plugins.
3. `nvm install --lts`
4. Set your terminal font to **JetBrainsMono Nerd Font**.
5. `gh auth login`

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
| `.config/ghostty/` | carried, but **not installed by bootstrap** (see below) |
| `.claude/agents/`, `AGENTS.md` | agent config, symlinked to `~/.claude/CLAUDE.md` |
| `.local/bin/tmux-sessionizer` | `prefix + f` popup, `tms` alias |

Not ported from the macOS repo: `aerospace/` (macOS-only), `btop/` and `htop/` (auto-generated stock defaults).

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

The config is carried over but `bootstrap.sh` does not install Ghostty, since it isn't in the Ubuntu archive and a work machine may be fine with the stock terminal.
To use it, install Ghostty separately and the config applies automatically.

## Uninstall

```bash
cd ~/ubuntu-dotfiles && stow -t ~ -D .
```

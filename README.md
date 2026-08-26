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
| `.claude/statusline.sh` | Claude Code status line (see below) |
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
| tree-sitter CLI | official release binary (apt has 0.20.8; nvim-treesitter needs 0.26.1+) |
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

### Neovim treesitter

`nvim-treesitter` has two branches and they are not interchangeable.
`master` is frozen and its README states plainly that **Neovim 0.12 is not supported**; `main` requires 0.12 or later.
Since `bootstrap.sh` installs the latest Neovim release, this repo tracks `main`.

Do not re-pin `master` to recover the old `nvim-treesitter.configs` API.
On 0.12 it breaks concretely: 0.12 dropped the `all = false` option to `add_directive`, so directives now always receive a *list* of nodes, and master's `#downcase!` passes that list straight to `get_node_text`.
Every bash heredoc then raises `attempt to call method 'range' (a nil value)` from the highlighter, which is most of `bootstrap.sh`.

Consequences of being on `main`, all reflected in `lua/plugins/treesitter.lua`:

- it cannot be lazy-loaded, so the spec is `lazy = false`
- `highlight.enable` / `indent.enable` are gone; the config starts the highlighter from a `FileType` autocmd and sets `indentexpr` itself
- folding is deliberately left alone there, because `nvim-ufo` owns `foldexpr` and `foldmethod`
- there is no `ignore_install`, so `latex` is simply absent from the language list rather than excluded from it
- parsers and queries live in `~/.local/share/nvim/site/`, not in the plugin directory

The tree-sitter CLI is a hard requirement of `main`, which is why `bootstrap.sh` installs it.
Ubuntu's `tree-sitter-cli` is 0.20.8 and `main` needs 0.26.1 or newer, so it comes from the official release binary instead.

### Claude Code status line

Claude Code's own footer only shows the permission mode.
`.claude/statusline.sh` adds a row above it with model, effort, context percentage, directory, git branch, churn, elapsed time, and cost.

It is width-aware because it has to be.
Claude Code captures the script's stdout instead of giving it a terminal, so `tput cols` reads nothing; the terminal width arrives in `COLUMNS` instead (Claude Code 2.1.153+).
The script fills segments in priority order, falls back to a shorter form where one exists, skips what will not fit, and spends whatever is left on a context bar.
A narrow split therefore degrades to just model and context rather than wrapping into the prompt.

Turning it on is one entry in `~/.claude/settings.json`, which is deliberately **not** in this repo - Claude Code rewrites that file whenever you change model or theme, and an atomic rewrite would replace a stowed symlink with a real file:

```json
{
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 0 }
}
```

Test it without launching Claude Code:

```bash
echo '{"model":{"display_name":"Opus 5"},"workspace":{"current_dir":"'"$HOME"'"},"context_window":{"used_percentage":42}}' \
  | COLUMNS=100 ~/.claude/statusline.sh
```

## Uninstall

```bash
cd ~/ubuntu-dotfiles && stow -t ~ -D .
```

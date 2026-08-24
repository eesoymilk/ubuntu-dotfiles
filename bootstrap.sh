#!/usr/bin/env bash
# Bootstrap this dotfiles setup on Ubuntu.
# Idempotent: safe to re-run. Assumes sudo is available.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
mkdir -p "$BIN"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- apt packages
log "Installing apt packages"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
	zsh stow tmux git curl wget unzip tar gzip ca-certificates \
	build-essential pkg-config \
	fzf fd-find bat ripgrep jq \
	wl-clipboard \
	python3 python3-venv

# Ubuntu ships these under different binary names to avoid collisions.
# The aliases in .zshrc and the fd call in tmux-sessionizer expect the
# upstream names, so bridge them here.
[ -e "$BIN/fd" ] || ln -sf "$(command -v fdfind)" "$BIN/fd"
[ -e "$BIN/bat" ] || ln -sf "$(command -v batcat)" "$BIN/bat"

export PATH="$BIN:$PATH"

# ------------------------------------------------------------------- neovim
# Ubuntu's archive lags badly; .zshrc already puts /opt/nvim on PATH.
if [ ! -x /opt/nvim/bin/nvim ]; then
	log "Installing Neovim (upstream tarball -> /opt/nvim)"
	tmp=$(mktemp -d)
	curl -fsSL -o "$tmp/nvim.tar.gz" \
		https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
	sudo rm -rf /opt/nvim
	sudo mkdir -p /opt/nvim
	sudo tar -xzf "$tmp/nvim.tar.gz" -C /opt/nvim --strip-components=1
	rm -rf "$tmp"
else
	log "Neovim already present at /opt/nvim"
fi

# --------------------------------------------------------------------- eza
if ! have eza; then
	log "Installing eza (upstream apt repo)"
	sudo mkdir -p /etc/apt/keyrings
	wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc |
		sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
	echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" |
		sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
	sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
	sudo apt-get update -qq && sudo apt-get install -y eza
fi

# ------------------------------------------------------------------ zoxide
have zoxide || { log "Installing zoxide"; curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; }

# -------------------------------------------------------------- oh-my-posh
have oh-my-posh || { log "Installing oh-my-posh"; curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$BIN"; }

# -------------------------------------------------------------------- yazi
if ! have yazi; then
	log "Installing yazi"
	tmp=$(mktemp -d)
	curl -fsSL -o "$tmp/yazi.zip" \
		https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip
	unzip -qo "$tmp/yazi.zip" -d "$tmp"
	install -m755 "$tmp"/yazi-*/yazi "$tmp"/yazi-*/ya "$BIN/"
	rm -rf "$tmp"
fi

# ----------------------------------------------------------------- lazygit
if ! have lazygit; then
	log "Installing lazygit"
	tmp=$(mktemp -d)
	ver=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": *"v\K[^"]*')
	curl -fsSL -o "$tmp/lg.tar.gz" "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${ver}_Linux_x86_64.tar.gz"
	tar -xzf "$tmp/lg.tar.gz" -C "$tmp" lazygit
	install -m755 "$tmp/lazygit" "$BIN/"
	rm -rf "$tmp"
fi

# --------------------------------------------------------------- lazydocker
have lazydocker || { log "Installing lazydocker"; curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | DIR="$BIN" bash; }

# -------------------------------------------------------------- git-delta
if ! have delta; then
	log "Installing git-delta"
	tmp=$(mktemp -d)
	ver=$(curl -fsSL "https://api.github.com/repos/dandavison/delta/releases/latest" | grep -Po '"tag_name": *"\K[^"]*')
	curl -fsSL -o "$tmp/delta.deb" "https://github.com/dandavison/delta/releases/download/${ver}/git-delta_${ver}_amd64.deb"
	sudo dpkg -i "$tmp/delta.deb"
	rm -rf "$tmp"
fi

# ---------------------------------------------------------------------- gh
have gh || { log "Installing GitHub CLI"; sudo apt-get install -y gh; }

# --------------------------------------------------------------------- nvm
if [ ! -d "$HOME/.nvm" ]; then
	log "Installing nvm"
	curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | PROFILE=/dev/null bash
fi

# -------------------------------------------------------------------- font
# Required: oh-my-posh and the eza --icons aliases render as tofu without it.
FONTDIR="$HOME/.local/share/fonts"
if ! fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
	log "Installing JetBrainsMono Nerd Font"
	mkdir -p "$FONTDIR"
	tmp=$(mktemp -d)
	curl -fsSL -o "$tmp/JetBrainsMono.zip" \
		https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
	unzip -qo "$tmp/JetBrainsMono.zip" -d "$FONTDIR/JetBrainsMono"
	fc-cache -f >/dev/null
	rm -rf "$tmp"
fi

# ------------------------------------------------------------------- stow
log "Stowing dotfiles into \$HOME"
cd "$DOTFILES"

# Pre-create these so stow links their *contents* instead of folding the whole
# directory into a single symlink. Without this, an app writing to ~/.config
# would be writing straight into the repo.
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.claude"

# Move conflicting real files aside rather than using `stow --adopt`, which
# would pull Ubuntu's defaults *into* the repo and overwrite the ported configs.
BACKUP="$HOME/dotfiles-backup-$(date +%Y%m%d%H%M%S)"
# stow's conflict wording differs by version, so match both:
#   2.3.x: "existing target is neither a link nor a directory: PATH"
#   2.4.x: "cannot stow SRC over existing target PATH since ..."
conflicts=$(stow -t "$HOME" -n . 2>&1 | sed -n \
	-e 's/.*existing target is neither a link nor a directory: *\(.*\)$/\1/p' \
	-e 's/.*cannot stow .* over existing target \(.*\) since .*/\1/p' |
	sed 's/[[:space:]]*$//' | sort -u || true)
if [ -n "$conflicts" ]; then
	log "Backing up conflicting files to $BACKUP"
	while IFS= read -r rel; do
		[ -z "$rel" ] && continue
		mkdir -p "$BACKUP/$(dirname "$rel")"
		mv "$HOME/$rel" "$BACKUP/$rel"
		echo "  moved $rel"
	done <<<"$conflicts"
fi

stow -t "$HOME" .
chmod +x "$HOME/.local/bin/tmux-sessionizer" 2>/dev/null || true

# Claude Code reads ~/.claude/CLAUDE.md; AGENTS.md is the single source.
mkdir -p "$HOME/.claude"
ln -sf "$HOME/AGENTS.md" "$HOME/.claude/CLAUDE.md"

# -------------------------------------------------------------- default shell
LOGIN_SHELL=$(getent passwd "$USER" | cut -d: -f7)
if [ "$(basename "$LOGIN_SHELL")" != "zsh" ]; then
	log "Setting zsh as the default shell"
	if chsh -s "$(command -v zsh)"; then
		NEED_RELOGIN=1
	else
		# Common on company LDAP/AD-managed accounts. Chain from bash instead:
		# terminal-agnostic, and survives switching emulators.
		echo "chsh failed (typical on managed accounts) - falling back to a .bashrc exec"
		LINE='[ -z "$ZSH_VERSION" ] && [ -x "$(command -v zsh)" ] && exec zsh -l'
		grep -qF "$LINE" "$HOME/.bashrc" 2>/dev/null || echo "$LINE" >>"$HOME/.bashrc"
	fi
else
	# passwd is already zsh, but $SHELL in this desktop session may still be
	# stale from an earlier login. Terminals that read $SHELL (Ghostty among
	# them) will keep launching the old shell until the session restarts.
	if [ "$(basename "${SHELL:-}")" != "zsh" ]; then NEED_RELOGIN=1; fi
fi

if [ -n "${NEED_RELOGIN:-}" ]; then
	log "Log out and back in before continuing."
	cat <<'EOF'
Your login shell is now zsh, but $SHELL in this desktop session is still
stale. Terminals that pick the shell from $SHELL (Ghostty does) will keep
launching the old one until you end the session. A new window is not
enough - log out and back in, or reboot.
EOF
fi

log "Then:"
cat <<'EOF'
  1. zinit auto-installs plugins on first zsh launch (wait a few seconds)
  2. Start tmux once; TPM auto-clones and installs plugins
  3. nvm install --lts
  4. Set your terminal font to "JetBrainsMono Nerd Font"
EOF

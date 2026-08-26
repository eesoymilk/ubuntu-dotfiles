#!/usr/bin/env bash
# Bootstrap this dotfiles setup on Ubuntu.
# Idempotent: safe to re-run. Assumes sudo is available.
#
# Every tool here is installed the way its own documentation prescribes.
# Where a hand-rolled fetch would be shorter it is still avoided: upstream
# changes asset names and layouts, and following the documented path is what
# keeps this script working a year from now.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
export PATH="$BIN:$PATH"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ----------------------------------------------------------------- platform
# Each project names its release assets differently for the same machine, so
# resolve every spelling once here instead of hardcoding x86_64 throughout.
case "$(uname -m)" in
x86_64)
	NVIM_ARCH=x86_64
	GO_ARCH=x86_64 # lazygit
	DEB_ARCH=amd64 # delta
	TS_ARCH=x64    # tree-sitter
	;;
aarch64 | arm64)
	NVIM_ARCH=arm64
	GO_ARCH=arm64
	DEB_ARCH=arm64
	TS_ARCH=arm64
	;;
*)
	echo "Unsupported architecture: $(uname -m)" >&2
	exit 1
	;;
esac
log "Detected $(uname -m) ($(. /etc/os-release && echo "$PRETTY_NAME"))"

# ---------------------------------------------------------------- apt packages
log "Installing apt packages"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
	zsh stow tmux git curl wget unzip tar gzip ca-certificates gnupg \
	build-essential pkg-config \
	fd-find bat ripgrep jq file \
	wl-clipboard \
	python3 python3-venv

# Ubuntu renames both binaries to avoid collisions with older packages.
# The `cat=bat` alias in .zshrc and the `fd` call in tmux-sessionizer expect
# the upstream names, so bridge them.
[ -e "$BIN/fd" ] || ln -sf "$(command -v fdfind)" "$BIN/fd"
[ -e "$BIN/bat" ] || ln -sf "$(command -v batcat)" "$BIN/bat"

# ------------------------------------------------------------------- neovim
# Official (neovim INSTALL.md): extract the release tarball under /opt.
# Upstream's own PATH line is /opt/nvim-linux-<arch>/bin, which would bake the
# architecture into .zshrc. Symlink a stable /opt/nvim so the shared config
# stays arch-agnostic.
if [ ! -x "/opt/nvim-linux-$NVIM_ARCH/bin/nvim" ]; then
	log "Installing Neovim (official tarball -> /opt/nvim-linux-$NVIM_ARCH)"
	tmp=$(mktemp -d)
	curl -fsSL -o "$tmp/nvim.tar.gz" \
		"https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$NVIM_ARCH.tar.gz"
	sudo rm -rf "/opt/nvim-linux-$NVIM_ARCH"
	sudo tar -C /opt -xzf "$tmp/nvim.tar.gz"
	rm -rf "$tmp"
else
	log "Neovim already present"
fi
sudo ln -sfn "/opt/nvim-linux-$NVIM_ARCH" /opt/nvim

# -------------------------------------------------------------- tree-sitter
# Official (tree-sitter CLI README): prebuilt release binary. Required by
# nvim-treesitter's main branch (0.26.1+, explicitly not the npm package);
# Ubuntu's tree-sitter-cli package is far too old (0.20.x).
if ! have tree-sitter; then
	log "Installing tree-sitter CLI (official release binary)"
	tmp=$(mktemp -d)
	curl -fsSL -o "$tmp/tree-sitter.gz" \
		"https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-$TS_ARCH.gz"
	gunzip "$tmp/tree-sitter.gz"
	install -m 755 "$tmp/tree-sitter" "$BIN/tree-sitter"
	rm -rf "$tmp"
fi

# --------------------------------------------------------------------- eza
# Official (eza INSTALL.md): the deb.gierens.de apt repository.
if ! have eza; then
	log "Installing eza (official apt repository)"
	sudo mkdir -p /etc/apt/keyrings
	wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc |
		sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
	echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" |
		sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
	sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
	sudo apt-get update -qq
	sudo apt-get install -y eza
fi

# -------------------------------------------------------------------- yazi
# Official (yazi docs): the project's own apt repository for Debian/Ubuntu.
# Replaces an earlier hand-rolled release-zip fetch.
if ! have yazi; then
	log "Installing yazi (official apt repository)"
	curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg |
		sudo tee /usr/share/keyrings/yazi-keyring.gpg >/dev/null
	echo 'deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main' |
		sudo tee /etc/apt/sources.list.d/yazi.list >/dev/null
	sudo apt-get update -qq
	sudo apt-get install -y yazi
fi

# --------------------------------------------------------------------- fzf
# Official (fzf README): git clone + install script.
#
# --no-update-rc is essential: the script appends PATH and shell-integration
# lines to ~/.zshrc, which here is a symlink into this repo, so the install
# would write itself into the dotfiles and follow us to other machines.
# .zshrc already puts ~/.fzf/bin on PATH and calls `fzf --zsh` itself.
if [ ! -d "$HOME/.fzf" ]; then
	log "Installing fzf (official git method)"
	git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
	"$HOME/.fzf/install" --all --no-update-rc
else
	log "Updating fzf"
	git -C "$HOME/.fzf" pull --ff-only --quiet || true
	"$HOME/.fzf/install" --all --no-update-rc >/dev/null
fi
# An earlier version of this script dropped an fzf here; ~/.local/bin precedes
# ~/.fzf/bin on PATH, so a leftover would shadow the real install.
if [ -f "$BIN/fzf" ] && [ ! -L "$BIN/fzf" ]; then
	rm -f "$BIN/fzf"
	echo "  removed stale $BIN/fzf"
fi

# ------------------------------------------------------------------ zoxide
# Official (zoxide README): the upstream install script.
have zoxide || {
	log "Installing zoxide (official install script)"
	curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
}

# -------------------------------------------------------------- oh-my-posh
# Official (ohmyposh.dev): install script; -d selects the target directory.
have oh-my-posh || {
	log "Installing oh-my-posh (official install script)"
	curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$BIN"
}

# ----------------------------------------------------------------- lazygit
# Official (lazygit README): apt where packaged (Ubuntu 25.10+), otherwise the
# documented release recipe, including their architecture mapping.
if ! have lazygit; then
	if apt-cache show lazygit >/dev/null 2>&1; then
		log "Installing lazygit (apt)"
		sudo apt-get install -y lazygit
	else
		log "Installing lazygit (official release recipe)"
		tmp=$(mktemp -d)
		LAZYGIT_VERSION=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" |
			grep -Po '"tag_name": *"v\K[^"]*')
		curl -fsSL -o "$tmp/lazygit.tar.gz" \
			"https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${GO_ARCH}.tar.gz"
		tar -xf "$tmp/lazygit.tar.gz" -C "$tmp" lazygit
		sudo install "$tmp/lazygit" -D -t /usr/local/bin/
		rm -rf "$tmp"
	fi
fi

# --------------------------------------------------------------- lazydocker
# Official (lazydocker README): the upstream install script.
have lazydocker || {
	log "Installing lazydocker (official install script)"
	curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh |
		DIR="$BIN" bash
}

# -------------------------------------------------------------- git-delta
# Official (delta docs): install the .deb from the releases page.
if ! have delta; then
	log "Installing git-delta (official .deb)"
	tmp=$(mktemp -d)
	DELTA_VERSION=$(curl -fsSL "https://api.github.com/repos/dandavison/delta/releases/latest" |
		grep -Po '"tag_name": *"\K[^"]*')
	curl -fsSL -o "$tmp/delta.deb" \
		"https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_${DEB_ARCH}.deb"
	sudo dpkg -i "$tmp/delta.deb"
	rm -rf "$tmp"
fi

# ---------------------------------------------------------------------- gh
# Official (cli.github.com): GitHub's apt repository.
if ! have gh; then
	log "Installing GitHub CLI (official apt repository)"
	sudo mkdir -p -m 755 /etc/apt/keyrings
	wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg |
		sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
	sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
		sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
	sudo apt-get update -qq
	sudo apt-get install -y gh
fi

# --------------------------------------------------------------------- nvm
# Official (nvm README): the upstream install script. PROFILE=/dev/null stops
# it appending to ~/.zshrc, which is a symlink into this repo; .zshrc already
# sources nvm itself.
if [ ! -d "$HOME/.nvm" ]; then
	log "Installing nvm (official install script)"
	curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh |
		PROFILE=/dev/null bash
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

hash -r

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

# ----------------------------------------------------------- yazi packages
# Unlike zinit and TPM, yazi does not self-install its plugins: init.lua
# `require`s them outright, so a fresh machine fails to start yazi at all.
# plugins/ and flavors/ are gitignored, so this has to run after stow puts
# package.toml in place. `install` honours the pinned revs; `upgrade` would
# move them and rewrite package.toml inside the repo.
if have ya; then
	log "Installing yazi plugins and flavors (ya pkg install)"
	ya pkg install
fi

# ------------------------------------------------------------------ verify
# Installing a tool and having it reachable are different things: the nvim
# tarball unpacks to a bin/ subdirectory, which is not the same as its root.
# Check against the PATH .zshrc actually builds, not this script's.
log "Verifying tools resolve on the shell PATH"
CHECK_PATH="$HOME/.local/bin:$HOME/.fzf/bin:/opt/nvim/bin:/usr/local/bin:/usr/local/go/bin:$PATH"
missing=""
for t in nvim tree-sitter tmux zsh stow fd bat eza zoxide oh-my-posh yazi ya lazygit lazydocker delta git gh rg jq; do
	PATH="$CHECK_PATH" command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
done
# Presence is not enough for fzf: an old apt build resolves fine but has no --zsh.
PATH="$CHECK_PATH" fzf --zsh >/dev/null 2>&1 || missing="$missing fzf(--zsh-unsupported)"
if [ -n "$missing" ]; then
	echo "  MISSING:$missing"
	echo "  (re-run bootstrap, or see README troubleshooting)"
else
	echo "  all tools resolve"
fi

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

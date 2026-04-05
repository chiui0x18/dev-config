#!/usr/bin/env bash
#
# dev.setup.macos.sh — Set up a fresh macOS box for software development.
# Avoids Homebrew wherever possible; uses git clone, curl, or official installers.
#
# PREREQUISITES (provided by macOS or Xcode CLT):
#   git, zsh (default shell), curl, make, vim, tmux
#   Install Xcode Command Line Tools first if missing: xcode-select --install
#
# DEPENDENCY ORDER (mandatory): Each step's prerequisites must be installed by a
# prior step. When adding new steps, verify dependencies are satisfied and place
# the step AFTER all its prerequisites.
#
#   1. Bootstrap: Verify Xcode CLT is installed (provides git, make, clang).
#   2. antidote: zsh plugin manager via git clone.
#      Depends on: git (step 1).
#   3. VIM >= 9.2 from source: Only if system vim is too old.
#      Depends on: git, make (step 1).
#   4. fzf: Via git clone + install --bin (latest, not Homebrew's stale version).
#      Depends on: git (step 1).
#   5. fd + bat + ripgrep + yq: Binary downloads from GitHub releases.
#      Depends on: curl (macOS built-in).
#   6. starship: Via official install script (curl).
#   7. zoxide: Via official install script (curl).
#   8. mise + tools: Via curl. Installs go, rust, python, uv.
#   9. coreutils: GNU date (gdate) needed by epoch() function.
#      This is the ONE item that requires Homebrew. Skipped if brew not found.
#  10. Dotfiles: Clone repo, symlink configs, copy gitconfig.
#      Depends on: git (step 1).
#
# USAGE:
#   ./dev.setup.macos.sh
#

set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: This script is for macOS only." >&2
  exit 1
fi

readonly ARCH="$(uname -m)"  # arm64 or x86_64
readonly VIM_REPO="https://github.com/vim/vim.git"
readonly VIM_MIN_VERSION="9.2"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() {
  printf "[%s] INFO: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

err() {
  printf "[%s] ERROR: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

# Download and extract a tar.gz from a URL into a destination directory.
# Usage: fetch_tar <url> <dest_dir>
fetch_tar() {
  local url="$1" dest="$2"
  mkdir -p "$dest"
  curl -fsSL "$url" | tar xz -C "$dest"
}

# Map uname -m to GitHub release arch naming conventions.
gh_arch() {
  if [[ "$ARCH" == "arm64" ]]; then echo "aarch64"; else echo "x86_64"; fi
}

# ---------------------------------------------------------------------------
# Install steps
# ---------------------------------------------------------------------------

install_bootstrap() {
  info "Checking Xcode Command Line Tools..."
  if ! xcode-select -p &>/dev/null; then
    info "Installing Xcode Command Line Tools (this may take a few minutes)..."
    xcode-select --install
    echo "Press Enter after Xcode CLT installation completes."
    read -r
  fi
  info "Xcode CLT: $(xcode-select -p)"
}

install_antidote() {
  info "Installing antidote (zsh plugin manager)..."
  if [[ -d "${HOME}/.antidote" ]]; then
    info "antidote already installed, pulling latest..."
    git -C "${HOME}/.antidote" pull
  else
    git clone --depth=1 https://github.com/mattmc3/antidote.git "${HOME}/.antidote"
  fi
}

install_vim() {
  if command -v vim &>/dev/null; then
    local current_version
    current_version="$(vim --version | head -1 | grep -oE '[0-9]+\.[0-9]+')"
    if [[ "$(printf '%s\n' "$VIM_MIN_VERSION" "$current_version" | sort -V | head -1)" == "$VIM_MIN_VERSION" ]]; then
      info "Vim ${current_version} already installed (>= ${VIM_MIN_VERSION}), skipping."
      # Still ensure vim-plug is present
      if [[ ! -f "${HOME}/.vim/autoload/plug.vim" ]]; then
        curl -fLo "${HOME}/.vim/autoload/plug.vim" --create-dirs \
          https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
      fi
      return 0
    fi
    info "Vim ${current_version} found but < ${VIM_MIN_VERSION}, rebuilding..."
  fi

  info "Building Vim from source..."
  local vim_tmp
  vim_tmp="$(mktemp -d)"
  git clone --depth 1 "$VIM_REPO" "${vim_tmp}/vim"

  cd "${vim_tmp}/vim"
  ./configure \
    --with-features=huge \
    --enable-multibyte \
    --enable-python3interp=yes \
    --enable-luainterp=yes \
    --enable-gui=no \
    --disable-mouse \
    --prefix=/usr/local

  make -j"$(sysctl -n hw.ncpu)"
  sudo make install
  cd /

  rm -rf "$vim_tmp"
  info "Vim installed: $(/usr/local/bin/vim --version | head -1)"

  curl -fLo "${HOME}/.vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
}

install_fzf() {
  info "Installing fzf via git clone (latest)..."
  if [[ -d "${HOME}/.fzf" ]]; then
    info "fzf directory already exists, pulling latest..."
    git -C "${HOME}/.fzf" pull
  else
    git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/.fzf"
  fi
  "${HOME}/.fzf/install" --bin
  mkdir -p "${HOME}/.local/bin"
  ln -sf "${HOME}/.fzf/bin/fzf" "${HOME}/.local/bin/fzf"
  info "fzf installed."
}

install_binaries() {
  mkdir -p "${HOME}/.local/bin"
  local ga
  ga="$(gh_arch)"

  # Bump these when upgrading
  local fd_version="10.2.0"
  local bat_version="0.25.0"
  local rg_version="14.1.1"

  # fd
  if ! command -v fd &>/dev/null; then
    info "Installing fd ${fd_version}..."
    local fd_tmp
    fd_tmp="$(mktemp -d)"
    fetch_tar "https://github.com/sharkdp/fd/releases/latest/download/fd-v${fd_version}-${ga}-apple-darwin.tar.gz" "$fd_tmp"
    cp "$fd_tmp"/fd-*/fd "${HOME}/.local/bin/fd"
    chmod +x "${HOME}/.local/bin/fd"
    rm -rf "$fd_tmp"
  fi
  info "fd: $(fd --version)"

  # bat
  if ! command -v bat &>/dev/null; then
    info "Installing bat ${bat_version}..."
    local bat_tmp
    bat_tmp="$(mktemp -d)"
    fetch_tar "https://github.com/sharkdp/bat/releases/latest/download/bat-v${bat_version}-${ga}-apple-darwin.tar.gz" "$bat_tmp"
    cp "$bat_tmp"/bat-*/bat "${HOME}/.local/bin/bat"
    chmod +x "${HOME}/.local/bin/bat"
    rm -rf "$bat_tmp"
  fi
  info "bat: $(bat --version)"

  # ripgrep
  if ! command -v rg &>/dev/null; then
    info "Installing ripgrep ${rg_version}..."
    local rg_tmp
    rg_tmp="$(mktemp -d)"
    fetch_tar "https://github.com/BurntSushi/ripgrep/releases/latest/download/ripgrep-${rg_version}-${ga}-apple-darwin.tar.gz" "$rg_tmp"
    cp "$rg_tmp"/ripgrep-*/rg "${HOME}/.local/bin/rg"
    chmod +x "${HOME}/.local/bin/rg"
    rm -rf "$rg_tmp"
  fi
  info "ripgrep: $(rg --version | head -1)"

  # yq
  if ! command -v yq &>/dev/null; then
    info "Installing yq..."
    local yq_arch
    if [[ "$ARCH" == "arm64" ]]; then yq_arch="arm64"; else yq_arch="amd64"; fi
    curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_darwin_${yq_arch}" \
      -o "${HOME}/.local/bin/yq"
    chmod +x "${HOME}/.local/bin/yq"
  fi
  info "yq: $(yq --version)"
}

install_starship() {
  info "Installing starship prompt..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
  info "starship installed: $(starship --version)"
}

install_zoxide() {
  info "Installing zoxide..."
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  info "zoxide installed."
}

install_mise_and_tools() {
  if ! command -v mise &>/dev/null && [[ ! -f "${HOME}/.local/bin/mise" ]]; then
    info "Installing mise..."
    curl https://mise.run | sh
  else
    info "mise already installed, skipping."
  fi

  export PATH="${HOME}/.local/bin:${PATH}"

  local tools=(go rust python uv)
  for tool in "${tools[@]}"; do
    if mise where "$tool" &>/dev/null; then
      info "${tool} already installed via mise, skipping."
    else
      info "Installing ${tool}@latest via mise..."
      mise use --global "${tool}@latest"
    fi
  done
  info "mise and tools installed."
}

install_coreutils() {
  # GNU coreutils provides gdate, needed by the epoch() shell function.
  # This is the one step that uses Homebrew — no clean alternative on macOS.
  if command -v gdate &>/dev/null; then
    info "gdate already available, skipping coreutils."
    return 0
  fi

  if command -v brew &>/dev/null; then
    info "Installing coreutils via Homebrew (for gdate)..."
    brew install coreutils
  else
    info "[SKIP] Homebrew not found. Install coreutils manually for gdate support."
    info "  The epoch() shell function will not work without gdate."
    info "  Install Homebrew: https://brew.sh then run: brew install coreutils"
  fi
}

# ---------------------------------------------------------------------------
# Dotfiles
# ---------------------------------------------------------------------------

readonly DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/chiui0x18/dotfiles.git}"
readonly DOTFILES_DIR="${HOME}/play/dotfiles"

install_dotfiles() {
  info "Setting up dotfiles from ${DOTFILES_REPO}..."

  if [[ -d "$DOTFILES_DIR" ]]; then
    info "Dotfiles repo already exists, pulling latest..."
    git -C "$DOTFILES_DIR" pull
  else
    mkdir -p "$(dirname "$DOTFILES_DIR")"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi

  # Symlink configs — changes propagate via `git pull` in the repo
  ln -sf "$DOTFILES_DIR/zshrc.comm" ~/.zshrc
  ln -sf "$DOTFILES_DIR/tmux.conf" ~/.tmux.conf
  ln -sf "$DOTFILES_DIR/zsh_plugins.txt" ~/.zsh_plugins.txt
  ln -sf "$DOTFILES_DIR/user_defined_functions.zsh" ~/.user_defined_functions.zsh
  ln -sf "$DOTFILES_DIR/vim/vimrc.vim" ~/.vimrc
  ln -sf "$DOTFILES_DIR/git/global.gitignore" ~/.gitignore_global
  mkdir -p ~/.config
  ln -sf "$DOTFILES_DIR/starship.toml" ~/.config/starship.toml

  # gitconfig is copied (not symlinked) because [user] section is environment-specific
  if [[ ! -f ~/.gitconfig ]]; then
    cp "$DOTFILES_DIR/git/global.gitconfig" ~/.gitconfig
    info "Copied gitconfig. Set your git identity with:"
    info "  git config --global user.name 'Your Name'"
    info "  git config --global user.email 'your@email.com'"
  else
    info "~/.gitconfig already exists, skipping (preserving [user] section)."
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  info "=== macOS dev box setup starting ==="

  install_bootstrap
  install_antidote
  install_vim
  install_fzf
  install_binaries
  install_starship
  install_zoxide
  install_mise_and_tools
  install_coreutils
  install_dotfiles

  info "=== macOS dev box setup complete ==="
}

main "$@"

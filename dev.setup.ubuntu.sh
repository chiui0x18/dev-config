#!/usr/bin/env bash
#
# dev.box.setup.ubuntu.sh — Set up a fresh Ubuntu (>= 22.04 LTS) box for software development.
#
# REQUIREMENTS:
#   1. CLI parameter: Takes one optional string argument — a space-separated list of
#      additional apt package names to install.
#
#   DEPENDENCY ORDER (mandatory): Each step's prerequisites must be installed by a
#   prior step. When adding new steps, verify dependencies are satisfied and place
#   the step AFTER all its prerequisites.
#
#   2. Bootstrap: apt update, install curl and build-essential (GNU make + toolchain).
#      curl may be absent on minimal Ubuntu installs; required by steps 5, 9, 10.
#   3. git: Latest stable via ppa:git-core/ppa.
#      Required by: vim (step 5, git clone), antidote (step 4, git clone),
#      fzf (step 7, git clone).
#   4. zsh + antidote: Install latest zsh via apt, install antidote (plugin manager),
#      set zsh as default shell via chsh.
#      Depends on: git (step 3).
#   5. VIM >= 9.2 from source (https://github.com/vim/vim):
#      - Configure: --with-features=huge --enable-multibyte
#        --enable-python3interp=yes --enable-luainterp=yes
#        --with-x --enable-gui=no --disable-mouse --prefix=/usr/local
#      - Build deps: libx11-dev libxt-dev ncurses-dev python3-dev lua5.4
#        liblua5.4-dev
#      - Build: make -j$(nproc) && sudo make install
#      - Clean up cloned repo after install.
#      Depends on: build-essential (step 2), git (step 3).
#   6. tmux: Via apt.
#   7. fzf (git clone) + fd + bat: fzf via git clone (apt versions too old for
#      `source <(fzf --zsh)`). fd and bat via apt (symlinked as fdfind→fd,
#      batcat→bat).
#      Depends on: git (step 3).
#   8. ripgrep + yq: ripgrep via apt. yq via snap (or binary download fallback).
#   9. starship: Cross-platform prompt. Via official install script (curl).
#      Depends on: curl (step 2).
#  10. zoxide: Via official install script (curl).
#      Depends on: curl (step 2).
#  11. mise + tools: Via curl https://mise.run | sh. Activate in ~/.bashrc.
#      Then install: go@latest, rust@latest, python@latest, uv@latest (all --global).
#      Depends on: curl (step 2).
#  12. Dotfiles: Clone dotfiles repo, symlink configs, copy gitconfig.
#      Depends on: git (step 3).
#      Override repo URL: export DOTFILES_REPO=<url> before running.
#  13. User-specified apt packages: Install whatever was passed via CLI arg.
#  14. Cleanup: apt-get autoremove (interactive) + apt-get clean.
#
# USAGE:
#   ./dev.box.setup.ubuntu.sh ["pkg1 pkg2 pkg3 ..."]
#
#   # Or bootstrap from github:
#   wget -qO - https://raw.githubusercontent.com/chiui0x18/dotfiles/refs/heads/master/dev.setup.ubuntu.sh | bash

set -euo pipefail

# Guard: this script uses sudo internally for apt/system installs.
# It must NOT be run as root (e.g. `sudo ./dev.box.setup.ubuntu.sh`),
# because user-space tools (mise, zoxide, antidote, dotfiles) would be
# installed under /root/ instead of the actual user's $HOME.
if [[ "$(id -u)" -eq 0 ]]; then
  echo "ERROR: Do not run this script with sudo. Run as your normal user:" >&2
  echo "  ./dev.box.setup.ubuntu.sh" >&2
  echo "The script uses sudo internally where needed." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

readonly BASHRC="${HOME}/.bashrc"
readonly VIM_REPO="https://github.com/vim/vim.git"
readonly VIM_MIN_VERSION="9.2"
readonly VIM_BUILD_DEPS=(
  libx11-dev libxt-dev ncurses-dev python3-dev
  lua5.4 liblua5.4-dev
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() {
  printf "[%s] INFO: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

err() {
  printf "[%s] ERROR: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

append_to_file() {
  local file="$1"
  local line="$2"
  if ! grep -qF "$line" "$file" 2>/dev/null; then
    printf '\n%s\n' "$line" >> "$file"
    info "Appended to ${file}: ${line}"
  else
    info "Already in ${file}: ${line}"
  fi
}

# ---------------------------------------------------------------------------
# Install steps
# ---------------------------------------------------------------------------

install_bootstrap() {
  info "Bootstrapping: apt update, curl, build-essential..."
  sudo apt-get update -y
  sudo apt-get install -y curl build-essential
}

install_git() {
  info "Installing latest git via ppa:git-core/ppa..."
  sudo add-apt-repository -y ppa:git-core/ppa
  sudo apt-get update -y
  sudo apt-get install -y git
  info "git installed: $(git --version)"
}

install_zsh() {
  info "Installing zsh..."
  sudo apt-get install -y zsh
  info "zsh installed: $(zsh --version)"

  # antidote: cross-platform zsh plugin manager (replaces oh-my-zsh)
  # Plugins are declared in ~/.zsh_plugins.txt and auto-cloned on first load.
  info "Installing antidote (zsh plugin manager)..."
  if [[ -d "${HOME}/.antidote" ]]; then
    info "antidote already installed, pulling latest..."
    git -C "${HOME}/.antidote" pull
  else
    git clone --depth=1 https://github.com/mattmc3/antidote.git "${HOME}/.antidote"
  fi

  info "Setting zsh as default shell..."
  sudo chsh -s "$(which zsh)" "$USER"
  info "Default shell set to zsh."
}

install_vim() {
  if command -v vim &>/dev/null; then
    local current_version
    current_version="$(vim --version | head -1 | grep -oP '\d+\.\d+')"
    if [[ "$(printf '%s\n' "$VIM_MIN_VERSION" "$current_version" | sort -V | head -1)" == "$VIM_MIN_VERSION" ]]; then
      info "Vim ${current_version} already installed (>= ${VIM_MIN_VERSION}), skipping build."
      return 0
    fi
    info "Vim ${current_version} found but < ${VIM_MIN_VERSION}, rebuilding..."
  fi

  info "Building Vim from source..."
  sudo apt-get install -y "${VIM_BUILD_DEPS[@]}"

  local vim_tmp
  vim_tmp="$(mktemp -d)"
  info "Cloning vim into ${vim_tmp}..."
  git clone --depth 1 "$VIM_REPO" "${vim_tmp}/vim"

  cd "${vim_tmp}/vim"
  ./configure \
    --with-features=huge \
    --enable-multibyte \
    --enable-python3interp=yes \
    --enable-luainterp=yes \
    --with-x \
    --enable-gui=no \
    --disable-mouse \
    --prefix=/usr/local

  make -j"$(nproc)"
  sudo make install
  cd /

  info "Cleaning up vim build directory..."
  rm -rf "$vim_tmp"
  info "Vim installed: $(/usr/local/bin/vim --version | head -1)"

  # Install vim-plug
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
}

install_tmux() {
  info "Installing tmux..."
  sudo apt-get install -y tmux
  info "tmux installed: $(tmux -V)"
}

install_fzf_fd_bat() {
  # fzf via git clone — Ubuntu apt repos ship outdated versions (0.29-0.44)
  # that lack `fzf --zsh` shell integration (requires 0.48+)
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

  # fd and bat via apt
  info "Installing fd-find, bat via apt..."
  sudo apt-get install -y fd-find bat

  # Ubuntu packages fd as 'fdfind' and bat as 'batcat' — create symlinks
  if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    ln -sf "$(which fdfind)" "${HOME}/.local/bin/fd"
    info "Created symlink: fd -> fdfind"
  fi
  if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    ln -sf "$(which batcat)" "${HOME}/.local/bin/bat"
    info "Created symlink: bat -> batcat"
  fi

  info "fzf, fd, bat installed."
}

install_ripgrep_yq() {
  info "Installing ripgrep..."
  sudo apt-get install -y ripgrep
  info "ripgrep installed: $(rg --version | head -1)"

  info "Installing yq via snap..."
  if command -v snap &>/dev/null; then
    sudo snap install yq
  else
    info "snap not available, installing yq via binary download..."
    local yq_url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
    curl -fsSL "$yq_url" -o "${HOME}/.local/bin/yq"
    chmod +x "${HOME}/.local/bin/yq"
  fi
  info "yq installed."
}

install_starship() {
  info "Installing starship prompt..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
  info "starship installed: $(starship --version)"
}

install_zoxide() {
  info "Installing zoxide via official install script..."
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  # zoxide init is already in the user's .zshrc; only add to .bashrc
  append_to_file "$BASHRC" 'eval "$(~/.local/bin/zoxide init bash)"'
  info "zoxide installed."
}

install_mise_and_tools() {
  if ! command -v mise &>/dev/null; then
    info "Installing mise..."
    curl https://mise.run | sh
    append_to_file "$BASHRC" 'eval "$(~/.local/bin/mise activate bash)"'
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

install_daily_utils() {
  local utils="tree ibus-rime gnome-tweaks xclip"
  info "Installing daily util packages: ${utils}"
  sudo apt-get install -y $utils
  info "Installed daily util packages: ${utils}"
}

install_user_packages() {
  local packages="$1"
  if [[ -z "$packages" ]]; then
    info "No user-specified packages to install."
    return 0
  fi
  info "Installing user-specified packages: ${packages}"
  # shellcheck disable=SC2086
  sudo apt-get install -y $packages
  info "User-specified packages installed."
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
  # Only copy if not present — avoid clobbering user's [user] section on re-run
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
  local user_packages="${1:-}"

  info "=== Ubuntu dev box setup starting ==="

  install_bootstrap
  install_git
  install_zsh
  install_vim
  install_tmux
  install_fzf_fd_bat
  install_ripgrep_yq
  install_starship
  install_zoxide
  install_mise_and_tools
  install_dotfiles
  install_user_packages "$user_packages"

  info "Cleaning up..."
  sudo apt-get autoremove
  sudo apt-get clean

  info "=== Ubuntu dev box setup complete ==="
}

main "$@"

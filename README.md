# dotfiles

Personal shell and editor configuration for macOS and Linux (Ubuntu, Amazon Linux 2/2023).

## Files

| File | Installs to | Purpose |
|------|-------------|---------|
| `zshrc.comm` | `~/.zshrc` | Zsh config — history, keybindings, PATH, aliases, tool init |
| `starship.toml` | `~/.config/starship.toml` | Starship prompt theme |
| `tmux.conf` | `~/.tmux.conf` | Tmux config |
| `zsh_plugins.txt` | `~/.zsh_plugins.txt` | Antidote plugin list |
| `user_defined_functions.zsh` | `~/.user_defined_functions.zsh` | Shell utility functions |
| `vim/` | `~/.vim/`, `~/.vimrc` | Vim config, ftplugin |
| `git/` | `~/.gitconfig`, `~/.gitignore_global` | Git config |

## Prerequisites

Install these before deploying dotfiles:

```bash
# Core
zsh vim tmux git

# CLI tools (used by zshrc/fzf config)
fzf fd bat ripgrep yq zoxide mise starship

# Zsh plugin manager
git clone --depth=1 https://github.com/mattmc3/antidote.git ~/.antidote

# macOS only
brew install coreutils  # provides gdate for epoch()
```

## Deploy

```bash
git clone <this-repo> ~/play/dotfiles && cd ~/play/dotfiles

# Symlink (preferred) or copy
ln -sf $PWD/zshrc.comm ~/.zshrc
ln -sf $PWD/tmux.conf ~/.tmux.conf
ln -sf $PWD/zsh_plugins.txt ~/.zsh_plugins.txt
ln -sf $PWD/user_defined_functions.zsh ~/.user_defined_functions.zsh
mkdir -p ~/.config && ln -sf $PWD/starship.toml ~/.config/starship.toml

# Open a new zsh session — antidote auto-clones plugins on first run.
```

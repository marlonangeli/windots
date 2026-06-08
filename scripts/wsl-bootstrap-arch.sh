#!/usr/bin/env bash
set -euo pipefail

if ! command -v pacman >/dev/null 2>&1; then
  echo "This script expects Arch Linux with pacman." >&2
  exit 1
fi

sudo pacman -Syu --needed --noconfirm \
  base-devel \
  git \
  curl \
  wget \
  unzip \
  zsh \
  tmux \
  starship \
  zoxide \
  ripgrep \
  fd \
  bat \
  eza \
  yazi \
  zellij \
  lazygit

if ! command -v mise >/dev/null 2>&1; then
  curl https://mise.run | sh
fi

echo "Arch WSL ready. Restart the shell, then run: mise install"

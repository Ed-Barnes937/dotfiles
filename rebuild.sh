#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles
exec sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/.dotfiles#MacPro

#!/bin/bash
# Update the pinned dependencies and apply them.
#
#   ./upgrade.sh            # all flake inputs
#   ./upgrade.sh nixpkgs    # just one
set -euo pipefail

cd "$(dirname "$0")"

# For detect_target, switch_profile and load_nix.
# shellcheck source=install.sh
source ./install.sh

load_nix

nix flake update "$@"
switch_profile "$(detect_target)"
nvim --headless "+Lazy! sync" +qa

echo
echo "Updated. Review and commit:"
git status --short flake.lock .config/nvim/lazy-lock.json

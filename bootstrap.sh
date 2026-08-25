#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v nix >/dev/null 2>&1; then
  echo "Nix is not installed."
  exit 1
fi

NIX_EXPERIMENTAL_FEATURES="nix-command flakes"
NIX_ARGS=(
  --extra-experimental-features
  "$NIX_EXPERIMENTAL_FEATURES"
)

# Command-line flags do not propagate to the nix commands started by Home
# Manager or nix-darwin. Export the setting so the complete bootstrap process,
# including its child processes, can use flakes on a new Nix installation.
if [ -n "${NIX_CONFIG:-}" ]; then
  NIX_CONFIG+=$'\n'
fi
NIX_CONFIG+="experimental-features = $NIX_EXPERIMENTAL_FEATURES"
export NIX_CONFIG

system="$(nix "${NIX_ARGS[@]}" eval --impure --raw \
  --expr 'builtins.currentSystem')"

username="${USER:-$(id -un)}"
home_directory="${HOME:?HOME is not set}"

echo "System: $system"
echo "User:   $username"
echo "Home:   $home_directory"
echo

cat > machine.nix <<EOF
{
  home.username = "$username";
  home.homeDirectory = "$home_directory";
}
EOF

echo "Generated machine.nix:"
cat machine.nix
echo

echo "Checking flake..."
nix "${NIX_ARGS[@]}" flake check path:.

backup_extension="before-home-manager-$(date +%Y%m%d-%H%M%S)"

echo "Activating Home Manager..."
nix "${NIX_ARGS[@]}" run nixpkgs#home-manager -- \
  switch -b "$backup_extension" --flake "path:.#${system}"

if [ "$system" = "aarch64-darwin" ]; then
  echo "Activating Nix Darwin..."
  sudo -H env "NIX_CONFIG=$NIX_CONFIG" nix "${NIX_ARGS[@]}" run github:nix-darwin/nix-darwin -- \
    switch --flake "path:.#${system}"
fi

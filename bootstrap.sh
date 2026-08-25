#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v nix >/dev/null 2>&1; then
  echo "Nix is not installed."
  exit 1
fi

NIX_ARGS=(
  --extra-experimental-features
  "nix-command flakes"
)

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

echo "Activating Home Manager..."
nix "${NIX_ARGS[@]}" run nixpkgs#home-manager -- \
  switch --flake "path:.#${system}"

if [ "$system" = "aarch64-darwin" ]; then
  echo "Activating Nix Darwin..."
  sudo -H nix "${NIX_ARGS[@]}" run github:nix-darwin/nix-darwin -- \
    switch --flake "path:.#${system}"
fi

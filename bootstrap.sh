#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v nix >/dev/null 2>&1; then
  echo "Nix is not installed."
  exit 1
fi

NIX_EXPERIMENTAL_FEATURES="nix-command flakes"
NUMTIDE_CACHE="https://cache.numtide.com"
NUMTIDE_CACHE_KEY="niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
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

configure_linux_numtide_cache() {
  local cache_config="/etc/nix/nix.conf.d/omahenix-numtide.conf"
  local include_line="!include $cache_config"

  if ! command -v systemctl >/dev/null 2>&1; then
    echo "The Numtide cache requires systemd-managed Nix on Linux." >&2
    return 1
  fi

  echo "Configuring the Numtide Nix binary cache..."
  sudo -v
  sudo /usr/bin/install -d -m 0755 /etc/nix/nix.conf.d
  sudo /usr/bin/tee "$cache_config" >/dev/null <<EOF
extra-substituters = $NUMTIDE_CACHE
extra-trusted-public-keys = $NUMTIDE_CACHE_KEY
EOF
  if ! sudo /usr/bin/grep -Fxq "$include_line" /etc/nix/nix.conf; then
    printf '\n%s\n' "$include_line" | sudo /usr/bin/tee -a /etc/nix/nix.conf >/dev/null
  fi
  if systemctl is-active --quiet nix-daemon.service; then
    sudo systemctl restart nix-daemon.service
  fi
}

configure_linux_tailscaled() {
  local tailscaled_binary
  local tailscaled_link="$home_directory/.nix-profile/bin/tailscaled"

  if ! command -v systemctl >/dev/null 2>&1; then
    echo "Tailscale requires systemd on Linux." >&2
    echo "Enable systemd in WSL and restart the distribution before re-running bootstrap." >&2
    return 1
  fi

  if [ ! -e "$tailscaled_link" ]; then
    echo "Nix-managed tailscaled was not installed at $tailscaled_link." >&2
    return 1
  fi
  tailscaled_binary="$(readlink -f "$tailscaled_link")"
  if [ ! -x "$tailscaled_binary" ]; then
    echo "Nix-managed tailscaled is not executable: $tailscaled_binary" >&2
    return 1
  fi

  echo "Configuring Tailscale system service..."
  sudo -v
  sudo /usr/bin/install -d -m 0755 /etc/systemd/system
  sudo /usr/bin/tee /etc/systemd/system/tailscaled.service >/dev/null <<EOF
[Unit]
Description=Tailscale node agent
Documentation=https://tailscale.com/kb/
Wants=network-pre.target
After=network-pre.target

[Service]
Type=simple
ExecStart=$tailscaled_binary --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock
Restart=on-failure
RestartSec=5
RuntimeDirectory=tailscale
RuntimeDirectoryMode=0755
StateDirectory=tailscale
StateDirectoryMode=0700

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable --now tailscaled.service
}

prepare_darwin_activation() {
  local etc_file
  local managed_target
  local current_target
  local backup_file
  local fish_login_shell

  echo "Preparing Nix Darwin activation..."
  sudo -v

  # nix-darwin requires these files to be absent before it can take ownership.
  # Preserve any installer- or user-provided versions rather than overwriting
  # them. Files already linked into /etc/static are nix-darwin managed.
  for etc_file in /etc/bashrc /etc/zshrc; do
    managed_target="/etc/static/${etc_file##*/}"
    current_target="$(/usr/bin/readlink "$etc_file" 2>/dev/null || true)"
    if [ -e "$etc_file" ] && [ "$current_target" != "$managed_target" ]; then
      backup_file="${etc_file}.before-nix-darwin"
      if [ -e "$backup_file" ]; then
        echo "Cannot preserve $etc_file: $backup_file already exists." >&2
        echo "Review the files and retry the bootstrap." >&2
        return 1
      fi

      echo "Preserving $etc_file as $backup_file"
      sudo /bin/mv "$etc_file" "$backup_file"
    fi
  done

  fish_login_shell="$home_directory/.nix-profile/bin/fish"
  if ! sudo /usr/bin/grep -Fxq "$fish_login_shell" /etc/shells; then
    echo "Adding Nix-managed Fish to /etc/shells"
    printf '%s\n' "$fish_login_shell" | sudo /usr/bin/tee -a /etc/shells >/dev/null
  fi
}

if [ "$system" = "aarch64-darwin" ]; then
  prepare_darwin_activation
elif [ "$system" = "x86_64-linux" ]; then
  configure_linux_numtide_cache
fi

echo "Checking flake..."
nix "${NIX_ARGS[@]}" flake check path:.

if [ "$system" = "aarch64-darwin" ]; then
  echo "Activating Nix Darwin..."
  sudo -H env "NIX_CONFIG=$NIX_CONFIG" nix "${NIX_ARGS[@]}" run github:nix-darwin/nix-darwin -- \
    switch --flake "path:.#${system}"
fi

backup_extension="before-home-manager-$(date +%Y%m%d-%H%M%S)"

echo "Activating Home Manager..."
nix "${NIX_ARGS[@]}" run nixpkgs#home-manager -- \
  switch -b "$backup_extension" --flake "path:.#${system}"

if [ "$system" = "x86_64-linux" ]; then
  configure_linux_tailscaled
fi

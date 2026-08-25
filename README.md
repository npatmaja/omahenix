# Omahenix

Omahenix sets up a consistent command-line environment with Nix, Home Manager, and Nix Darwin. It installs useful tools, configures Fish, enables the Hydro prompt and Node version manager (NVM), applies the Catppuccin Macchiato color theme, and installs Kitty through Nix Darwin on macOS.

The current setup supports:

- Apple Silicon macOS (`aarch64-darwin`)
- 64-bit Intel or AMD Linux (`x86_64-linux`)

## What it installs

- Fish shell
- Hydro prompt
- NVM for Fish
- `jq`, `htop`, `btop`, `gh`, `lazygit`, and `hunk`

The setup also adds common Go, Cargo, Zig, PostgreSQL, Homebrew, and local binary folders to Fish's command search path.

## Install Nix for the first time

Omahenix uses Nix's multi-user (daemon) installation. On macOS or Linux, install it from the official installer:

```sh
sh <(curl -L https://nixos.org/nix/install) --daemon
```

Follow the installer prompts, open a new terminal, then confirm that Nix works:

```sh
nix --version
```

The installer needs administrator access and creates the `/nix` store. Review the [official Nix installation documentation](https://nixos.org/download/) before running it if you need an alternative installer or an existing Nix installation.

If Nix is installed but Fish cannot find it, run:

```fish
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
```

## Set up your environment

Clone the repository, enter its directory, and run:

```sh
./bootstrap.sh
```

The script:

1. Detects your operating system, username, and home folder.
2. Creates `machine.nix` with local settings. This file stays outside Git.
3. Checks the configuration.
4. Applies the Home Manager setup, preserving any conflicting existing configuration files with a timestamped `.before-home-manager-*` suffix.
5. On Apple Silicon macOS, prompts for `sudo` and applies the Nix Darwin system configuration, including Kitty.

On Apple Silicon macOS, the script adds the Nix-managed Fish path to `/etc/shells` before activating Home Manager. On Linux, follow any Fish login-shell command printed by the script, then run `./bootstrap.sh` again.

Start a fresh Fish session after setup:

```fish
exec ~/.nix-profile/bin/fish -l
```

Confirm that the main commands are available:

```fish
nix --version
nvm --version
```

The prompt should now use Hydro.

### Nix Darwin on macOS

`./bootstrap.sh` automatically applies the Apple Silicon Nix Darwin configuration after Home Manager. It prompts for `sudo`; Nix Darwin installs Kitty as a system package. Confirm it after activation:

```sh
kitty --version
```

Before the first Nix Darwin activation, the script preserves existing `/etc/bashrc` and `/etc/zshrc` as `.before-nix-darwin` backups so Nix Darwin can take ownership. It will stop rather than overwrite an existing backup; review that backup before retrying. Nix Darwin manages the replacement files after a successful switch.

## Make changes

Edit `home.nix` to add packages or change Fish settings. Check your work without applying it:

```sh
nix --extra-experimental-features "nix-command flakes" flake check path:.
```

Use `path:.` in manual commands because `machine.nix` is generated locally and ignored by Git.

Apply your changes with:

```sh
./bootstrap.sh
```

For Fish changes, restart the shell with `exec fish -l`. Home Manager cannot change a shell process that is already running.

## Update package versions

Refresh package versions, review the change to `flake.lock`, and apply the setup again:

```sh
nix --extra-experimental-features "nix-command flakes" flake update
./bootstrap.sh
```

`./bootstrap.sh` also re-applies the Nix Darwin system configuration on Apple Silicon macOS.

Commit `flake.lock` so every machine uses the same package versions.

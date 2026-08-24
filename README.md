# Omahenix

Omahenix sets up a consistent command-line environment with Nix and Home Manager. It installs useful tools, configures Fish, enables the Hydro prompt and Node version manager (NVM), and applies the Catppuccin Macchiato color theme.

The current setup supports:

- Apple Silicon macOS (`aarch64-darwin`)
- 64-bit Intel or AMD Linux (`x86_64-linux`)

## What it installs

- Fish shell
- Hydro prompt
- NVM for Fish
- `jq`, `htop`, `btop`, `gh`, `lazygit`, and `hunk`

The setup also adds common Go, Cargo, Zig, PostgreSQL, Homebrew, and local binary folders to Fish's command search path.

## Requirements

Install Nix before using this repository. Confirm that it works:

```sh
nix --version
```

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
4. Applies the Home Manager setup.

The setup may ask you to add Fish to `/etc/shells` before macOS or Linux will accept it as your login shell. Follow the command printed by the script, then run `./bootstrap.sh` again.

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

Commit `flake.lock` so every machine uses the same package versions.

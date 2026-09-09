---
tags: [tailscale, macos, nix-darwin, operations]
created: 2026-09-09
updated: 2026-09-09
version: 1.0.0
status: stable
---

# Keep Tailscale.app on macOS

## Overview

Tailscale.app includes both the menu-bar interface and its own networking daemon. It cannot remain functional if its daemon is disabled. This repository's nix-darwin service also starts a `tailscaled` daemon, so choose one daemon owner per Mac.

To keep the Tailscale GUI, keep Tailscale.app installed and disable the nix-darwin Tailscale service.

## Configuration

In `darwin.nix`, replace:

```nix
services.tailscale.enable = true;
```

with:

```nix
services.tailscale.enable = false;
```

Alternatively, remove the line entirely; `false` records the intended choice explicitly.

Apply the configuration:

```sh
./bootstrap.sh
```

Nix-darwin removes its launchd job during the switch. Tailscale.app remains installed in `/Applications`, including its menu-bar UI and its own daemon.

## Verification

1. Open **Tailscale.app** from Applications.
2. Confirm the menu-bar icon reports the expected connection state.
3. Run:

   ```sh
   tailscale status
   ```

   The command should list the node and its peers. If the app is signed out, authenticate from the GUI.

## Switching to the Nix-managed daemon

Use this only when the menu-bar GUI is not needed:

1. Quit the app:

   ```sh
   osascript -e 'quit app "Tailscale"'
   ```

2. Remove it using the mechanism that installed it:

   ```sh
   brew uninstall --cask tailscale
   ```

   when it was installed with Homebrew; otherwise drag `/Applications/Tailscale.app` to Trash in Finder. A terminal-only removal is:

   ```sh
   sudo rm -rf /Applications/Tailscale.app
   ```

3. Set `services.tailscale.enable = true;` in `darwin.nix`.
4. Run `./bootstrap.sh`.
5. Authenticate the daemon once with `tailscale up`.

Do not leave Tailscale.app active while `services.tailscale.enable = true`; two daemons can conflict over networking, DNS, sockets, and state.

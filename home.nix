{
  config,
  pkgs,
  lib,
  ...
}:

let
  home = config.home.homeDirectory;
  catppuccinFish = pkgs.fetchFromGitHub {
    owner = "catppuccin";
    repo = "fish";
    rev = "5fc5ae9c2ec22eb376cb03ce76f0d262a38960f3";
    hash = "sha256-3KNWYXfOMzZovdjwjBpjSH8cVlD4CO2QmQcCyQE4Dac=";
  };

  repos = "${home}/.local/src";
  dotfiles = "${repos}/dotfiles";
  nvimConfig = "${repos}/kckstrt.nvim";
in
{
  home.stateVersion = "26.11";

  home.packages = with pkgs; [
    jq
    htop
    btop
    gh
    lazygit
    hunk
    herdr

    # programming languages
    odin
    rustup

    neovim
    tree-sitter
    git
    ripgrep
    fd

    gnumake

    # Formatter
    stylua
    nixfmt

    # LSPs
    lua-language-server
    gopls
    typescript-language-server
    marksman
    vscode-langservers-extracted
    tailwindcss-language-server
    nixd
    ols # odin
  ];

  programs.home-manager.enable = true;

  # Fish
  programs.fish = {
    enable = true;
    plugins = [
      {
        name = "hydro";
        src = pkgs.fishPlugins.hydro.src;
      }
      {
        name = "nvm";
        src = pkgs.fishPlugins.nvm.src;
      }
    ];

    shellInit = ''
      # GUI terminals can inherit a removed Homebrew Fish path in $SHELL even
      # when Kitty starts the Nix-managed Fish binary. Export the stable Nix
      # profile path so child processes, including Herdr, use the right shell.
      set -gx SHELL "${config.home.profileDirectory}/bin/fish"

      # Multi-user Nix installation
      if not set --query __ETC_PROFILE_NIX_SOURCED
        if test -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
          source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
        end
      end

      # User-installed binaries
      fish_add_path --path --move --prepend "$HOME/.local/bin"
      fish_add_path --path --move --prepend "$HOME/go/bin"

      # Zig Version Manager
      set -gx ZVM_INSTALL "$HOME/.zvm/self"
      fish_add_path --path --move --prepend "$HOME/.zvm/bin"
      fish_add_path --path --move --prepend "$ZVM_INSTALL"

      # Cargo
      if test -f "$HOME/.cargo/env.fish"
        source "$HOME/.cargo/env.fish"
      end

      # Homebrew stays available as fallback during migration.
      if test -d /opt/homebrew/bin
        fish_add_path --path --move --append /opt/homebrew/bin
      end

      if test -d /opt/homebrew/opt/libpq/bin
        fish_add_path --path --move --append /opt/homebrew/opt/libpq/bin
      end
    '';

    interactiveShellInit = ''
      # Color-aware command-line tools inherit this setting from the terminal.
      set --erase --global NO_COLOR

      # Hydro prompt configuration
      set hydro_color_pwd brmagenta
      set hydro_color_git $fish_color_command
      set hydro_color_error $fish_color_error
      set hydro_color_prompt --dim brcyan
      set hydro_color_duration --dim $fish_color_command

      set --universal nvm_default_version lts
    '';

    shellInitLast = ''
      fish_add_path --path --move --prepend "$HOME/.nix-profile/bin"

      # Fish syntax highlighting theme
      fish_config theme choose catppuccin-macchiato
    '';
  };

  programs.kitty = {
    enable = true;
    package = null;
    themeFile = "Catppuccin-Macchiato";
    font = {
      package = pkgs.jetbrains-mono;
      name = "JetBrains Mono";
      size = 13;
    };
    settings = {
      shell = "${config.home.profileDirectory}/bin/fish -l";
      clipboard_control = "write-clipboard write-primary read-clipboard read-primary";
    };
    shellIntegration.enableFishIntegration = true;
  };

  # Keep the account login shell pointed at the stable profile link rather than
  # a versioned Nix-store path. The profile directory derives from the home
  # directory supplied by machine.nix.
  home.activation.setFishLoginShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    fish_login_shell="${config.home.profileDirectory}/bin/fish"
    ${
      if pkgs.stdenv.hostPlatform.isDarwin then
        ''
          current_shell="$(/usr/bin/dscl . -read "/Users/$USER" UserShell 2>/dev/null | /usr/bin/awk '{ print $2 }')"
          chsh_command=/usr/bin/chsh
          grep_command=/usr/bin/grep

          # Terminal.app may retain an explicit shell from before the Homebrew
          # migration even after the account login shell has been changed.
          terminal_shell="$(/usr/bin/defaults read com.apple.Terminal Shell 2>/dev/null || true)"
          if [ "$terminal_shell" = "/opt/homebrew/bin/fish" ]; then
            /usr/bin/defaults write com.apple.Terminal Shell -string "$fish_login_shell"
          fi
        ''
      else
        ''
          current_shell="$(${pkgs.glibc.bin}/bin/getent passwd "$USER" | ${pkgs.gawk}/bin/awk -F: '{ print $7 }')"
          chsh_command=${pkgs.util-linux}/bin/chsh
          grep_command=${pkgs.gnugrep}/bin/grep
        ''
    }

    if [ "$current_shell" != "$fish_login_shell" ]; then
      if "$grep_command" -Fxq "$fish_login_shell" /etc/shells; then
        "$chsh_command" -s "$fish_login_shell" "$USER"
      else
        echo "Fish is managed by Home Manager, but the OS will not accept it as a login shell yet."
        echo "Run once: sudo sh -c 'printf \\\"%s\\\\n\\\" $fish_login_shell >> /etc/shells'"
        echo "Then re-run home-manager switch."
      fi
    fi
  '';

  xdg.configFile."fish/themes/catppuccin-macchiato.theme".source =
    "${catppuccinFish}/themes/catppuccin-macchiato.theme";

  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink nvimConfig;

  xdg.configFile."git".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/git";

  # Keep personal Git identity out of the tracked dotfiles repository. The
  # shared Git config includes this file, and it is created only on first use.
  home.activation.createGitLocalConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    git_config_dir="${dotfiles}/config/git"
    git_local_config="$git_config_dir/config.local"

    if [ ! -d "$git_config_dir" ]; then
      echo "Git dotfiles directory does not exist: $git_config_dir" >&2
      exit 1
    fi

    malformed_git_local_config='[user]\n    name = Your Name\n    email = your@email.com\n'
    should_create_git_local_config=false

    if [ ! -e "$git_local_config" ]; then
      should_create_git_local_config=true
    elif [ "$(cat "$git_local_config")" = "$malformed_git_local_config" ]; then
      echo "Repairing malformed Git identity placeholder: $git_local_config"
      should_create_git_local_config=true
    fi

    if [ "$should_create_git_local_config" = true ]; then
      if [ -n "''${DRY_RUN-}" ]; then
        echo "Would create Git identity placeholder: $git_local_config"
      else
        (
          umask 077
          printf '%s\n' \
            '[user]' \
            '    name = Your Name' \
            '    email = your@email.com' \
            > "$git_local_config"
        )
      fi
    fi
  '';

  # Fisher previously owned these plugins. Remove only its copies so Fish does
  # not load the same plugin twice after Home Manager takes ownership.
  home.activation.removeFisherHydroAndNvm = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    $DRY_RUN_CMD rm -f \
      "$HOME/.config/fish/conf.d/hydro.fish" \
      "$HOME/.config/fish/conf.d/nvm.fish" \
      "$HOME/.config/fish/functions/fish_mode_prompt.fish" \
      "$HOME/.config/fish/functions/fish_prompt.fish" \
      "$HOME/.config/fish/functions/_nvm_index_update.fish" \
      "$HOME/.config/fish/functions/_nvm_list.fish" \
      "$HOME/.config/fish/functions/_nvm_version_activate.fish" \
      "$HOME/.config/fish/functions/_nvm_version_deactivate.fish" \
      "$HOME/.config/fish/functions/nvm.fish" \
      "$HOME/.config/fish/completions/nvm.fish"

    $DRY_RUN_CMD ${pkgs.fish}/bin/fish --no-config --command '
      set --erase --universal _fisher_jorgebucaran_2F_hydro_files; or true
      set --erase --universal _fisher_jorgebucaran_2F_nvm_2E_fish_files; or true

      set -l retained_plugins
      for plugin in $_fisher_plugins
        if not contains -- $plugin jorgebucaran/hydro jorgebucaran/nvm.fish
          set --append retained_plugins $plugin
        end
      end
      if set --query retained_plugins[1]
        set --universal _fisher_plugins $retained_plugins
      else
        set --erase --universal _fisher_plugins; or true
      end
    '
  '';

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}

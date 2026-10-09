{ machine, pkgs, ... }:

{
  system.primaryUser = machine.home.username;
  system.stateVersion = 6;

  services.openssh = {
    enable = true;
    extraConfig = ''
      PubkeyAuthentication yes
      PasswordAuthentication no
    '';
  };

  services.tailscale.enable = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };

  environment.systemPackages = with pkgs; [
    kitty
    omniwm
  ];

  # Start OmniWM from the copy nix-darwin refreshes on every switch, so login
  # never launches a stale Nix-store version.
  launchd.user.agents.omniwm.serviceConfig = {
    ProgramArguments = [
      "/usr/bin/open"
      "/Applications/Nix Apps/OmniWM.app"
    ];
    RunAtLoad = true;
  };

  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];
}

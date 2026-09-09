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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    kitty
  ];

  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];
}

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
  ];

  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];
}

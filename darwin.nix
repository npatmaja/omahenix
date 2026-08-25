{ machine, pkgs, ... }:

{
  system.primaryUser = machine.home.username;
  system.stateVersion = 6;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    kitty
  ];

  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];
}

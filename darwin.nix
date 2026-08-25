{ machine, pkgs, ... }:

{
  system.primaryUser = machine.home.username;
  system.stateVersion = 6;

  environment.systemPackages = with pkgs; [
    kitty
  ];

  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];
}

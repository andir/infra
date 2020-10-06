{ pkgs, config, ... }:
{
  imports = [
    ./base
    ./ssh
    ./dns.nix
  ];

  programs.mosh.enable = true;

  environment.systemPackages = with pkgs; [
    tmux
  ];

  documentation.enable = false;
  documentation.nixos.enable = false;
}

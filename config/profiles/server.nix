{ pkgs, config, ... }:
{
  imports = [
    ./base
    ./ssh
    ./dns.nix
  ];

  # FIXME: on the systemd v245 nixpkgs branch mosh fails to build
  programs.mosh.enable = config.networking.hostName != "bertha";

  environment.systemPackages = with pkgs; [
    tmux
  ];

  documentation.enable = false;
  documentation.nixos.enable = false;
}

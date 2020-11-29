{ pkgs, ... }:
{

  imports = [
    ../../profiles/server.nix
    ./hardware.nix
  ];

  deployment = {
    targetHost = "92.60.37.85";
    targetUser = "root";
  };

  networking = {
    hostName = "kappa";
    domain = "h4ck.space";
  };

  system.stateVersion = "20.09";
}

{ pkgs, lib, ... }:
{
  networking.nameservers = [ "::1" ];
  services.resolved.enable = false;
  services.unbound = {
    enable = true;
    allowedAccess = [
      "::1/128"
      "127.0.0.0/8"
    ];
  };
}

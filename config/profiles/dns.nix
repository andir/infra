{ pkgs, lib, ... }:
{
  networking.nameservers = [ "::1" ];
  services.resolved.enable = false;
  networking.resolvconf = {
    useLocalResolver = false;
    extraConfig = "name_servers='127.0.1.53'";
  };
  services.kresd = {
    interfaces = lib.mkDefault [
      "127.0.1.53"
    ];
  };
  services.unbound = {
    enable = lib.mkDefault true;
    interfaces = [ "127.0.1.53" ];
    allowedAccess = [
      "::1/128"
      "127.0.0.0/8"
    ];
  };
}

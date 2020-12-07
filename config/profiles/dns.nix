{ pkgs, lib, ... }:
{
  networking.nameservers = [ "::1" ];
  services.resolved.enable = false;
  networking.resolvconf = {
    # TODO: file upstream (nixpkgs) issue about non-standard address resolvers
    useLocalResolver = false;
    extraConfig = "name_servers='127.0.1.53'";
  };
  services.kresd = {
    listenPlain = lib.mkDefault [
      "127.0.1.53:53"
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
  systemd.services.unbound.serviceConfig.RestrictAddressFamilies = [ "AF_NETLINK" ]; # required since some nixpkgs bump…
}

{ pkgs, config, lib, ... }:
{
  services.unifi = {
    enable = true;
    unifiPackage = pkgs.unifiStable;
  };

  services.nginx = {
    enable = true;
    virtualHosts."unifi.epsilon.rammhold.de" = {
      locations."/" = {
        proxyPass = "https://";
        proxyWebsockets = true;
        extraConfig = let
          networks = lib.flatten (
            map (
              iface:
                (
                  map
                    (addr: addr.address + "/${toString addr.prefixLength}")
                    (iface.v4Addresses ++ iface.v6Addresses)
                )
            ) config.router.downstreamInterfaces
          );
        in
          ''
            ${lib.concatMapStringsSep "\n" (addr: "allow ${addr};") networks}
            deny   all;
          '';
      };
    };
  };
}

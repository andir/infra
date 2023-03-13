{ pkgs, config, lib, ... }:
{
  services.unifi = {
    enable = false;
    #mongodbPackage = pkgs.mongodb-4_2;
    unifiPackage = pkgs.unifi.overrideAttrs (
      _: rec {
        #   version = "6.5.54";
        #   src = pkgs.fetchurl {
        #     url = "https://dl.ubnt.com/unifi/${version}/unifi_sysvinit_all.deb";
        #     sha256 = "sha256-M2gYqKZi0czFgfWx0tTW43b+aUVqS6Mg+misRB9/Fes=";
        #   };
      }
    );
  };


  # users.users.unifi.group = "unifi";
  # users.groups.unifi = { };

  services.nginx = {
    # disabled since unifi seems to request logins for unknown reason..
    enable = true;
    virtualHosts."unifi.epsilon.rammhold.de" = {
      locations."/" = {
        proxyPass = "https://localhost:8443";
        proxyWebsockets = true;
        extraConfig =
          let
            networks = lib.flatten (
              map
                (
                  iface:
                  (
                    map
                      (addr: addr.address + "/${toString addr.prefixLength}")
                      (iface.v4Addresses ++ iface.v6Addresses)
                  )
                )
                config.router.downstreamInterfaces
            );
          in
          ''
            ${lib.concatMapStringsSep "\n" (addr: "allow ${addr};") networks}
            deny   all;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
      };
    };
  };
}

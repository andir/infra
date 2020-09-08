{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.router;

  addressesOptions = types.submodule {
    options = {
      address = mkOption {
        type = types.str;
      };
      prefixLength = mkOption {
        type = types.int;
      };
    };
  };

  downstreamInterfaceOptions = types.submodule {
    options = {
      interface = mkOption {
        type = types.str;
      };
      subnetId = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      v6Addresses = mkOption {
        type = types.listOf addressesOptions;
      };
      v4Addresses = mkOption {
        type = types.listOf addressesOptions;
      };

      dnsOverTls = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable DNS-o-TLS on this interface. This will make unbound listen on
          the address on port 853. You must ensure that unbound is configured
          with the desired certificate.
        '';
      };
    };
  };
in
{
  options.router = {
    enable = mkEnableOption "enable the router module";
    upstreamInterfaces = mkOption {
      description = "upstream interfaces";
      type = types.listOf types.str;
    };

    downstreamInterfaces = mkOption {
      description = "client interfaces";
      type = types.listOf downstreamInterfaceOptions;
    };
  };

  config = mkIf cfg.enable {

    # ensure we have a few sane network debugging tools available
    environment.systemPackages = with pkgs; [ tcpdump dnstracer nmap telnet ];
    programs.mtr.enable = true;

    # Can not use this as it pulls in a bunch of garbage rules
    networking.useNetworkd = false;
    networking.dhcpcd.enable = mkForce false;
    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    services.unbound.interfaces = lib.mkForce (
      [ "127.0.1.52" "::1" ] ++ (
        lib.flatten (
          map (
            iface:
              (map (addr: addr.address) iface.v4Addresses)
              ++ (map (addr: addr.address) iface.v6Addresses)
              ++ (
                if iface.dnsOverTls then (
                  (map (addr: "${addr.address}@853") iface.v4Addresses)
                  ++ (map (addr: "${addr.address}@853") iface.v6Addresses)
                ) else []
              )
          )
            cfg.downstreamInterfaces
        )
      )
    );
    environment.etc."debug".text = builtins.toJSON config.services.unbound.interfaces;
    # allow everyone to access the resolver, filtering will be done in the firewall
    services.unbound.allowedAccess = [ "::1/128" "127.0.0.0/8" "::/0" "0.0.0.0/0" ];

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/662313c7-5fa6-460f-80a8-c3aaa26fad80";
      fsType = "ext4";
    };

    systemd.services."systemd-networkd".environment.SYSTEMD_LOG_LEVEL = "debug";

    systemd.network = let
      mkUpstreamIfConfig = name: nameValuePair "00-${name}" {
        enable = true;
        networkConfig = {
          Description = "upstream network config for ${name}";
          IPv6AcceptRA = true;
          #ipmasquerade = true; # fixme: hows does that work on the inside?
          #ipforward = "yes";
          DHCP = "yes";
          #ipv6prefixdelegation = "dhcpv6";
        };
        linkConfig = {
          RequiredForOnline = "routable";
        };
        matchConfig = {
          Name = name;
        };
        dhcpV4Config = {
          UseDNS = false;
          UseRoutes = true;
        };
        dhcpV6Config = {
          PrefixDelegationHint = "::/48";
        };
        ipv6PrefixDelegationConfig = {
          Managed = true;
          OtherInformation = true;
        };
        routes = [
          {
            routeConfig = {
              Destination = "fd00::/8";
              Type = "blackhole";
            };
          }
          {
            routeConfig = {
              Destination = "10.0.0.0/8";
              Type = "blackhole";
            };
          }
          {
            routeConfig = {
              Destination = "172.16.0.0/12";
              Type = "blackhole";
            };
          }
          {
            routeConfig = {
              Destination = "192.168.0.0/16";
              Type = "blackhole";
            };
          }

        ];
      };
      mkClientIfConfig = conf: let
        v = nameValuePair "00-${conf.interface}" {
          enable = true;
          matchConfig = {
            Name = conf.interface;
          };

          addresses = (
            map (
              addr:
                { addressConfig.Address = "${addr.address}/${toString addr.prefixLength}"; }
            ) (conf.v4Addresses ++ conf.v6Addresses)
          )
          ++ [ { addressConfig.Address = "::/64"; } ];

          networkConfig = {
            DHCPServer = mkDefault true;
            IPv6PrefixDelegation = "yes";
          };

          dhcpServerConfig = {
            PoolOffset = 10;
            EmitDNS = true;
            DNS = (map (addr: addr.address) conf.v4Addresses);
            EmitNTP = true;
            EmitRouter = true;
            EmitTimezone = true;
            Timezone = "Europe/Berlin";
          };

          ipv6PrefixDelegationConfig = {
            RouterLifetimeSec = 300;
            EmitDNS = true;
            DNS = "_link_local";
          };

          extraConfig = (
            lib.optionalString (conf.subnetId != null) ''
              [DHCPv6PrefixDelegation]
              SubnetId=${conf.subnetId}
              Assign=true
            ''
          )
            #  + ''
            #  [DHCPv6]
            #  AssignAcquiredDelegatedPrefixAddress=yes
            #''
          ;

          ipv6Prefixes = [
            {
              ipv6PrefixConfig = {
                AddressAutoconfiguration = true;
                PreferredLifetimeSec = 1800;
                ValidLifetimeSec = 1800;
              };
            }
          ] ++ (
            map (
              addr: {
                ipv6PrefixConfig = {
                  Prefix = "${addr.address}/${toString addr.prefixLength}";
                };
              }
            ) conf.v6Addresses
          );
        };
      in
        v;
      upstreamConfig = builtins.listToAttrs (map mkUpstreamIfConfig cfg.upstreamInterfaces);
      downstreamConfig = builtins.listToAttrs (map mkClientIfConfig cfg.downstreamInterfaces);
    in
      {
        enable = true;
        networks = mkMerge [
          upstreamConfig
          downstreamConfig
          {
            "99-main" = {
              networkConfig = {
                IPv6AcceptRA = lib.mkForce false;
                DHCP = lib.mkForce "no";
              };
              linkConfig = {
                Unmanaged = lib.mkForce "yes";
              };
            };
          }
        ];
      };
  };
}

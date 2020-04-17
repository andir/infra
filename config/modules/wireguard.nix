{ config, pkgs, lib, ... }:
let
  wireguardPeerConfig = { name, ... }: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
      };

      interfaceName = lib.mkOption {
        internal = true;
        type = lib.types.str;
      };
      remoteEndpoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      remotePort = lib.mkOption {
        type = lib.types.port;
        default = 11001;
      };
      remotePublicKey = lib.mkOption{
        type = lib.types.str;
      };
      localPort = lib.mkOption {
        type = lib.types.port;
      };
      remoteAddresses = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
    };
    config = {
      inherit name;
      interfaceName = "wg-${builtins.substring 0 10 name}";
    };
  };
in
{
  options.h4ck.wireguardBackbone = {
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/wireguardBackbone";
    };
    privateKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.h4ck.wireguardBackbone.dataDir}/wireguard.key";
    };
    publicKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.h4ck.wireguardBackbone.dataDir}/wireguard.pub";
    };

    addresses = lib.mkOption {
      default = [];
      type = lib.types.listOf (lib.types.str);
    };

    peers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule wireguardPeerConfig);
      default = {};
    };
  };

  config = let
    cfg = config.h4ck.wireguardBackbone;
  in lib.mkIf (cfg.peers != {} && cfg.addresses != []) {
    environment.systemPackages = [ pkgs.wireguard ];
    systemd.tmpfiles.rules = [
      "d ${config.h4ck.wireguardBackbone.dataDir} 700 systemd-network systemd-network - -"
    ];
    systemd.services."wireguardBackbone-generate-keys" = {
      path = [ pkgs.wireguard ];
      after = [ "systemd-tmpfiles-setup.service" ];
      before = [ "network.target" ];
      partOf = [ "network-pre.target" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        set -ex
        test -e ${config.h4ck.wireguardBackbone.privateKeyFile} || {
          wg genkey > ${config.h4ck.wireguardBackbone.privateKeyFile}
        }
        test -e ${config.h4ck.wireguardBackbone.publicKeyFile} || {
          wg pubkey < ${config.h4ck.wireguardBackbone.privateKeyFile} > ${config.h4ck.wireguardBackbone.publicKeyFile}
        }
        chmod 600 ${config.h4ck.wireguardBackbone.privateKeyFile}
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "systemd-network";
        RemainAfterExit = true;
      };
    };
    boot.extraModulePackages = [ config.boot.kernelPackages.wireguard ];
    services.bird2 = {
      enable = lib.mkDefault true;
      config = let
        firstV4Net = lib.head (lib.filter (addr: ! (builtins.elem ":" (builtins.split "" addr))) cfg.addresses);
        firstV4Address = lib.head (builtins.split "/" firstV4Net);
      in ''
        # FIXME: move the router id somewhere else. What if we would do proper peering as well?
        router id ${firstV4Address};

        protocol device {
          scan time 60;
          interface "wg-*" {};
        };

        protocol direct {
          ipv4;
          ipv6;
          interface "*";
        };

        protocol kernel kv4 {
          learn;
          persist;
          ipv4 {
            import all;
            export filter {
              if net ~ 172.20.0.0/14 then accept;
              reject;
            };
          };
        };

        protocol kernel kv6 {
          learn;
          persist;
          ipv6 {
            import all;
            export filter {
              if net ~ fd00::/8 then accept;
              reject;
            };
          };
        };

        protocol babel wgbackbone {
          randomize router id yes;
          interface "wg-*" {
            type wired;
          };
          ipv4 {
            table master4;
            export filter {
              if (source = RTS_BABEL) || (net ~ 172.20.0.0/14) then {
                accept;
              }
              reject;
            };
            import all;
          };
          ipv6 {
            table master6;
            export filter {
              if (source = RTS_BABEL) || (net ~ fd00::/8) then {
                accept;
              }
              reject;
            };
          };
        };
      '';
    };
    networking.firewall.allowedUDPPorts = [ 6696 ] ++  lib.mapAttrsToList (_: peer: peer.localPort) config.h4ck.wireguardBackbone.peers;
    systemd.network = lib.mkMerge (
      lib.mapAttrsToList (
        name: peer:
          {
            enable = lib.mkDefault true;
            netdevs = {
              "40-${peer.interfaceName}" = {
                netdevConfig = {
                  Kind = "wireguard";
                  MTUBytes = "1300";
                  Name = "${peer.interfaceName}";
                };
                extraConfig = ''
                  [WireGuard]
                  PrivateKeyFile = ${toString cfg.privateKeyFile}
                  ListenPort = ${toString peer.localPort}

                  [WireGuardPeer]
                  PublicKey = ${peer.remotePublicKey}
                  AllowedIPs=::/0, 0.0.0.0/0
                  ${lib.optionalString (peer.remoteEndpoint != null) "Endpoint=${peer.remoteEndpoint}:${toString peer.remotePort}"}
                '';
              };
            };

            networks = {
              "40-${peer.interfaceName}" = {
                matchConfig = {
                  Name = "${peer.interfaceName}";
                };
                networkConfig = {
#                  DHCP = false;
#                  IPv6AcceptRA = false;
                  LinkLocalAddressing = "ipv6";
                };
                addresses = map (
                  addr:
                    { addressConfig.Address = addr; }
                ) cfg.addresses;
                routes = map (
                  addr:
                    { routeConfig = { Destination = addr; }; }
                  ) (lib.traceValSeq peer.remoteAddresses);
              };
            };
          }
      )
        config.h4ck.wireguardBackbone.peers
    );
  };
}

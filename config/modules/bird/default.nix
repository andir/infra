{ config, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption mkOption types mkMerge optionalString;
  cfg = config.h4ck.bird;
in
{
  options.h4ck.bird = {
    enable = mkEnableOption "Enable the bird wrapper module";
    routerId = mkOption {
      type = types.str;
    };
    srcpref = mkOption {
      type = types.submodule {
        options = {
          v4Address = mkOption { type = types.nullOr types.str; default = null; };
          v6Address = mkOption { type = types.nullOr types.str; default = null; };
        };
      };
    };

    rfc6890Blackhole = mkOption {
      description = "Blackhole all RFC6890 networks";
      default = true;
      type = types.bool;
    };
  };
  config = mkIf cfg.enable {
    users.groups.bird2.members = mkIf (config.users.users ? andi) [ "andi" ];
    services.bird2 = {
      enable = true;
      config = mkMerge [
        ''
          router id ${cfg.routerId};

          protocol device {
            scan time 60;
          };

          protocol direct {
            ipv4;
            ipv6;
            interface "*";
          };

          #
          # Global kernel protocols that import and export all routes
          # The idea is that each of the protocols that feeds into these tables
          # is responsible for ensuring no gargabe is being passed in.
          # i.e. the babel protocol that should only carry DN42 networks should
          # filter accordingly., the external BGP peers should be limited to
          # their transitive set of routes through ROA / RPKI / ….
          #
          protocol kernel kv4 {
            learn;
            persist;
            ipv4 {
              import all;
              export filter {
                ${lib.optionalString (cfg.srcpref.v4Address != null) ''
                  krt_prefsrc = ${cfg.srcpref.v4Address};
                ''}
                accept;
              };

            };
          }
          protocol kernel kv6 {
            learn;
            persist;
            ipv6 {
              import all;
              export filter{
                ${lib.optionalString (cfg.srcpref.v6Address != null) ''
                  krt_prefsrc = ${cfg.srcpref.v6Address};
                ''}
                accept;
              };
            };
          }
        ''
        (
          optionalString cfg.rfc6890Blackhole ''
              #
              # This blackholes all commonly called "private" address spaces.
              # We should never emit traffic to any of these networks without having a more specifc route.
              # The list is not complete. A few selected networks have been left
              # out as thouse would likely not play well with the overall network
              # configuration. i.e. we already know that fe80::/64 is link
              # specific and the kernel does the right thing for us.
              #
              protocol static rfc6890_blackhole_v4 {
                ipv4;
              ${lib.concatMapStringsSep "\n" (p: "  route ${p} blackhole;") [
              "0.0.0.0/8"
              "10.0.0.0/8"
              "100.64.0.0/10"
              "169.254.0.0/16"
              "172.16.0.0/12"
              "192.0.0.0/24"
              "192.0.0.0/29"
              "192.0.2.0/24"
              "192.88.99.0/24"
              "192.168.0.0/16"
              "198.18.0.0/15"
              "198.51.100.0/24"
              "203.0.113.0/24"
              "240.0.0.0/4"
            ]}
              };
              protocol static rfc6890_blackhole_v6 {
                ipv6;
              ${lib.concatMapStringsSep "\n" (p: "  route ${p} blackhole;") [
              "64:ff9b::/96"
              "::ffff:0:0/96"
              "100::/64"
              "2001::/23"
              "2001::/32"
              "2001:2::/48"
              "2001:db8::/32"
              "2001:10::/28"
              "2002::/16"
              "fc00::/7"
            ]}
              }
          ''
        )
      ];
    };
  };
}

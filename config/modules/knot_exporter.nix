{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.h4ck.prometheus.exporters.knot_exporter;
in
{

  options.h4ck.prometheus.exporters.knot_exporter = {
    enable = mkEnableOption "Enable knot_exporter";

    knotPackage = mkOption {
      type = types.package;
      default = pkgs.knot-dns;
    };

    port = mkOption {
      type = types.port;
      default = 9053;
    };

    # dummy option, I don't use this in my systems
    openFirewall = mkOption {
      default = false;
      type = types.bool;
    };
  };
  config = mkIf cfg.enable {
    systemd.services.knot_exporter = {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        ${pkgs.knot_exporter} \
          --knot-library-path ${pkgs.knot-dns.out}/lib/libknot.so \
          --web-listen-addr :: \
          --web-listen-port ${toString cfg.port}
      '';
      serviceConfig.User = "knot";
    };
  };
}

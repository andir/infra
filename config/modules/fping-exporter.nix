{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.h4ck.prometheus.exporters.fping_exporter;
in
{
  options.h4ck.prometheus.exporters.fping_exporter = {
    enable = mkEnableOption "fping_exporter";
    port4 = mkOption {
      type = types.port;
      default = 9604;
    };
    port6 = mkOption {
      type = types.port;
      default = 9606;
    };

  };
  config = mkIf cfg.enable {
    security.wrappers = {
      fping4.source = "${pkgs.fping}/bin/fping";
      fping6.source = "${pkgs.fping}/bin/fping";
    };

    users.users.fping_exporter = {};
    systemd.services.fping_exporter4 = {
      after = [ "network.target" "knot.service" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        ${config.security.wrapperDir}/fping4 --help
        exec ${pkgs.fping_exporter}/bin/fping-exporter \
          --listen [::]:${toString cfg.port4} \
          --period 15 \
          --fping ${config.security.wrapperDir}/fping4
      '';
      serviceConfig = {
        User = "fping_exporter";
      };
    };
    systemd.services.fping_exporter6 = {
      after = [ "network.target" "knot.service" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        exec ${pkgs.fping_exporter}/bin/fping-exporter \
          --listen [::]:${toString cfg.port6} \
          --period 15 \
          --fping ${config.security.wrapperDir}/fping6
      '';
      serviceConfig = {
        User = "fping_exporter";
      };
    };
  };
}

{ pkgs, config, lib, ... }:
with lib;
let
  cfg = config.h4ck.publictransport;
  src = pkgs.sources.publictransport;

  python = pkgs.python38.withPackages (p: with p; [ flask lxml pytz ]);
in
{
  options.h4ck.publictransport = {
    enable = mkEnableOption "publictransport";
    port = mkOption {
      type = types.port;
      default = 1339;
    };
    virtualHost = mkOption {
      type = types.str;
      default = "darmstadt.io";
    };
  };

  config = mkIf cfg.enable {
    services.nginx.virtualHosts.${cfg.virtualHost} = {
      locations."/".proxyPass = "http://localhost:${toString cfg.port}";
    };

    systemd.services.publictransport = {
      wantedBy = [ "multi-user.target" ];
      path = [ python ];
      environment.LANG = "en_US.UTF-8";
      script = ''
        cd ${src}
        python3 -m publictransport -p ${toString cfg.port}
      '';
      serviceConfig = {
        DynamicUser = true;
        ProtectSystem = "full";
        PrivateTmp = true;
        Restart = "always";
      };
    };
  };

}

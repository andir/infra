{ lib, pkgs, config, ... }:
let cfg = config.h4ck.spacesbot; in
{
  options.h4ck.spacesbot = {
    enable = lib.mkEnableOption "spacesbot";
    homeserver = lib.mkOption {
      type = lib.types.str;
    };
    user = lib.mkOption {
      type = lib.types.str;
    };
    roomId = lib.mkOption {
      type = lib.types.str;
    };
    accessTokenFile = lib.mkOption {
      type = lib.types.str;
    };
  };


  config = lib.mkIf cfg.enable {
    systemd.services.spacesbot = {
      path = [
        pkgs.spacesbot
      ];
      script = ''
        set -e
        export SPACESBOT_ACCESS_TOKEN=$(<$CREDENTIALS_DIRECTORY/access-token)
        exec spacesbot --homeserver "${cfg.homeserver}" --user "${cfg.user}" "${cfg.roomId}"
      '';

      startAt = "hourly";

      serviceConfig = {
        DynamicUser = true;
        LoadCredential = [
          "access-token:${cfg.accessTokenFile}"
        ];
        RuntimeDirectory = "spacesbot";
        StateDirectory = "spacesbot";
        WorkingDirectory = "/var/lib/spacesbot";
      };
    };
  };
}

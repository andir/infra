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
        exec spacesbot --homeserver "${cfg.homeserver}" --user "${cfg.user}" "${cfg.roomId}" join
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
    systemd.services.spacesbot-tree = {
      path = [
        pkgs.spacesbot
        pkgs.pandoc
      ];
      script = ''
        set -e
        export SPACESBOT_ACCESS_TOKEN=$(<$CREDENTIALS_DIRECTORY/access-token)
        spacesbot --homeserver "${cfg.homeserver}" --user "${cfg.user}" "${cfg.roomId}" tree index.md
        exec pandoc -f markdown -t html -s index.md > index.html
      '';

      startAt = "hourly";

      serviceConfig = {
        ExecStartPost =
          let
            script = pkgs.writeShellScript "copy-outputs" ''
              cp /var/lib/spacesbot-tree/index.html /var/lib/logs-static-index/index.html
              chmod -R +rX /var/lib/logs-static-index
            '';
          in
          "+${script}";
        DynamicUser = true;
        LoadCredential = [
          "access-token:${cfg.accessTokenFile}"
        ];
        RuntimeDirectory = "spacesbot-tree";
        StateDirectory = "spacesbot-tree";
        WorkingDirectory = "/var/lib/spacesbot-tree";
      };
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/logs-static-index 750 nginx nginx -"
    ];
  };
}

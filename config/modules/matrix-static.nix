{ pkgs, config, lib, ... }:
let
  cfg = config.h4ck.matrix-static;
in
{

  options.h4ck.matrix-static = {
    enable = lib.mkEnableOption "matrix-static";
    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 8000;
    };

    homeserverUrl = lib.mkOption {
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.matrix-static = {
      environment.PORT = toString cfg.listenPort;
      path = [ pkgs.matrix-static ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        set -e
        cd $RUNTIME_DIRECTORY
        register-guest -config-file="$PWD/config.json" -homeserver-url="${cfg.homeserverUrl}" -media-base-url="${cfg.homeserverUrl}"
        ln -s ${pkgs.matrix-static.assets} assets
        exec matrix-static -enable-prometheus-metrics -config-file="$PWD/config.json"
      '';

      serviceConfig = {
        DynamicUser = true;
        User = "matrix-static";
        Group = "matrix-static";
        RuntimeDirectory = "matrix-static";
      };
    };
  };
}

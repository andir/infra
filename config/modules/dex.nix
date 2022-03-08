{ lib, pkgs, config, utils, ... }:
let
  cfg = config.h4ck.dex;
in
{
  options.h4ck.dex = {
    enable = lib.mkEnableOption "dex";
    package = lib.mkOption {
      default = pkgs.dex;
      type = lib.types.package;
    };

    issuer = lib.mkOption {
      type = lib.types.str;
    };

    storageConfig = lib.mkOption {
      default = {
        type = "memory";
      };
      type = lib.types.attrs;
    };

    listenAddress = lib.mkOption {
      default = "[::1]";
      type = lib.types.str;
    };

    listenPort = lib.mkOption {
      default = 2379;
      type = lib.types.port;
    };

    frontendConfig = lib.mkOption {
      default = { };
      type = lib.types.attrs;
    };

    loggerConfig = lib.mkOption {
      default = {
        level = "debug";
        format = "text";
      };
      type = lib.types.attrs;
    };
    expiryConfig = lib.mkOption {
      default = {
        deviceRequests = "5m";
        signingKeys = "6h";
        idTokens = "24h";
      };
    };

    staticClientsConfig = lib.mkOption {
      default = [ ];
      type = lib.types.listOf lib.types.attrs;
    };

    oauth2Config = lib.mkOption {
      default = { };
      type = lib.types.attrs;
    };

    connectorsConfig = lib.mkOption {
      default = [ ];
      type = lib.types.listOf lib.types.attrs;
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.dex = {
      isSystemUser = true;
      group = "dex";
    };
    users.groups.dex = { };
    systemd.services.dex =
      let
        configAttr = {
          inherit (cfg) issuer;
          storage = cfg.storageConfig;
          web.http = "${cfg.listenAddress}:${toString cfg.listenPort}";
          fronted = cfg.frontendConfig;
          logger = cfg.loggerConfig;
          expiry = cfg.expiryConfig;
          oauth2 = cfg.oauth2Config;
          connectors = cfg.connectorsConfig;
          staticClients = cfg.staticClientsConfig;
          enablePasswordDB = false;
        };

        configFile = "/run/dex/config.yml";
        configFleGenerator = utils.genJqSecretsReplacementSnippet configAttr "/run/dex/config.yml";
      in
      {
        path = [
          cfg.package
        ];
        wantedBy = [ "multi-user.target" ];
        script = "dex serve ${configFile}";
        serviceConfig = {
          ExecStartPre = [
            "+${(pkgs.writeShellScript "dex-config.sh" ''
              umask u=rwx,g=,o=
              ${configFleGenerator}
              chown dex /run/dex/config.yml
            '')}"
          ];
          RuntimeDirectory = "dex";
          User = "dex";
          Group = "dex";
        };
      };
  };
}

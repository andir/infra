{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.h4ck.ipv6watch;

  interpreter = cfg.python.withPackages (_: cfg.pythonPackages);
in {
  options.h4ck.ipv6watch = {
    enable = mkEnableOption "Enable ipv6.watch";

    python = mkOption {
      default = pkgs.python3;
      type = types.package;
    };

    pythonPackages = mkOption {
      default = with cfg.python.pkgs; [
        jinja2
        pyyaml
        jsonschema
        aiodns
        prometheus_client
      ];
      type = types.listOf types.package;
    };

    virtualHost = mkOption {
      default = "ipv6.watch";
      type = types.str;
    };

    repoUrl = mkOption {
      default = "https://github.com/andir/ipv6.watch.git";
      type = types.str;
    };

    repoBranch = mkOption {
      default = "master";
      type = types.str;
    };

    updateOn = mkOption {
      type = types.either (types.listOf types.str) types.str;
      default = [ "hourly" ];
    };

    outputDir = mkOption {
      type = types.str;
      default = "/var/lib/ipv6.watch-public";
    };
  };

  config = mkIf cfg.enable {

    users.users."ipv6.watch" = {
      isSystemUser = true;
      createHome = true;
      home = cfg.outputDir;
      group = "ipv6.watch";
    };

    users.groups."ipv6.watch" = {
      members = mkIf config.services.nginx.enable [ "nginx" ];
    };

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.virtualHost}" = {
        root = "${cfg.outputDir}";
        enableACME = true;
        forceSSL = true;
      };
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.outputDir}' 0755 ipv6.watch ipv6.watch"
    ];
    systemd.services."ipv6.watch-update" = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      path = [
        pkgs.git
        pkgs.rsync
        interpreter
      ];
      script = ''
        set -ex
        test -e repo || git clone "${cfg.repoUrl}" -b "${cfg.repoBranch}" repo
        cd repo
        git fetch origin
        git reset --hard "${cfg.repoBranch}"
        git prune -v
        git gc --force
        OUT_DIR=$(mktemp -d)
        python generate.py "$OUT_DIR"
        chmod a+rX -R "$OUT_DIR"
        cp -T -r "$OUT_DIR/" "${cfg.outputDir}/"
        rsync -rv dist/ "${cfg.outputDir}/" --delete --filter="protect index.html" --filter='protect metrics'
        rm -rf $OUT_DIR
      '';

      startAt = cfg.updateOn;

      serviceConfig = {
        User = "ipv6.watch";
        Group = "ipv6.watch";
        ReadWritePaths = [ cfg.outputDir "/var/lib/ipv6.watch" ];
        StateDirectory = "ipv6.watch";
        WorkingDirectory="/var/lib/ipv6.watch";
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHostname = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        LocalPersonality = true;
        RestrictRealtime = true;
        PrivateMounts = true;
        ProtectSystem = "full";
        NoNewPrivileges = true;
      };
    };
  };
}

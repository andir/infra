{ config, lib, pkgs, ... }:
let
  cfg = config.h4ck.prosody.coturn;
  pcfg = config.h4ck.prosody;

  secretFileDir = "/var/lib/coturn-secret";

  coturnInitialDB = pkgs.runCommand "coturn-sql-schema"
    {
      nativeBuildInputs = [ pkgs.sqlite ];
    } ''
    sqlite3 coturn.sqlite < ${pkgs.coturn.src}/turndb/schema.sql
    mv coturn.sqlite $out
  '';
in
{
  options.h4ck.prosody.coturn = {
    enable = lib.mkEnableOption "Prosody Coturn Integration";
  };

  config = lib.mkIf (cfg.enable && pcfg.enable) {

    h4ck.prosody.extraCommunityModules = [
      "turncredentials"
    ];

    services.coturn = {
      enable = true;
      realm = "stun.${pcfg.serverName}";
      use-auth-secret = true;
      listening-ips = [ ];
      min-port = 20000;
      max-port = 20100;
      extraConfig = ''
        userdb=/var/lib/turnserver/database.sqlite
        verbose
      '';
    };

    services.prosody.extraConfig = ''
      turncredentials_host = "stun.${pcfg.serverName}"
      turncredentials_secret = ENV_TURN_SECRET
      turncredentials_port = 3479
    '';

    networking.firewall.allowedTCPPorts = [ 3479 ] ++ lib.range 20000 20100;
    networking.firewall.allowedUDPPorts = [ 3479 ] ++ lib.range 20000 20100;

    users.groups."coturn-secret-users".members = [ "prosody" "turnserver" ];

    systemd.tmpfiles.rules = [
      "d ${secretFileDir} 740 turnserver coturn-secret-users -"
      "d /var/lib/turnserver 740 turnserver turnserver -"
    ];

    systemd.services."coturn-secret-generator" = {
      path = [ pkgs.sqlite ];
      after = [ "systemd-tmpfiles-setup.service" ];
      before = [ "prosody.service" "coturn.service" ];
      wantedBy = [ "multi-user.target" ];

      script = ''
        set -e
        if ! test -e ${secretFileDir}/secret; then
          tr -dc A-Za-z0-9 </dev/urandom 2>/dev/null | head -c 64 > /tmp/secret
          chmod 440 /tmp/secret
          mv /tmp/secret ${secretFileDir}/secret
        fi

        if ! test -e ${secretFileDir}/secret.env; then
          echo "TURN_SECRET=$(<${secretFileDir}/secret)" > /tmp/secret.env
          chmod 440 /tmp/secret.env
          mv /tmp/secret.env ${secretFileDir}/secret.env
        fi

        if ! test -e /var/lib/coturn/database.sqlite; then
          cp ${coturnInitialDB} /tmp/database.sqlite
          chmod u+rw /tmp/database.sqlite
          chmod og-rwx /tmp/database.sqlite
          echo "INSERT INTO turn_secret (realm, value) VALUES ('stun.${pcfg.serverName}', '$(<${secretFileDir}/secret)');" | sqlite3 /tmp/database.sqlite
          cp /tmp/database.sqlite /var/lib/turnserver/database.sqlite
        fi
      '';

      serviceConfig = {
        User = "turnserver";
        Group = "coturn-secret-users";
        Type = "oneshot";
        RemainAfterExit = "true";
        PrivateTmp = true;
      };
    };

    systemd.services.prosody.serviceConfig.EnvironmentFile = "${secretFileDir}/secret.env";
  };
}

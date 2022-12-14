{ pkgs, ... }:
{
  users.groups.zrepl-clients = { };
  users.users.zeta-backups = {
    isSystemUser = true;
    openssh.authorizedKeys.keys = [
      ''
        command="zrepl stdinserver zeta",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIli6KfN92fAn4D6aSCwwB0jmRZqPcQdtvxj5aIcj95L root@zeta
      ''
    ];
    group = "zrepl-clients";
    useDefaultShell = true;
  };
  services.zrepl = {
    enable = true;
    settings = {
      jobs = [
        {
          name = "zeta-to-omicron";
          type = "sink";
          recv = {
            properties."inherit" = [
              "encryption"
              "compression"
            ];
            placeholder.encryption = "inherit";
          };
          serve = {
            type = "stdinserver";
            client_identities = [
              "zeta"
            ];
          };
          root_fs = "tank/backups/zrepl";
        }
        {
          name = "omicron-to-zeta";
          type = "push";
          send = { };
          connect = {
            type = "ssh+stdinserver";
            host = "zeta.rammhold.de";
            user = "omicron-backups";
            port = 22;
            identity_file = "/root/.ssh/id_ed25519";
          };
          filesystems = {
            "tank/backups<" = true;
            "tank/backups/zrepl<" = false;
            "tank/vaultwaren" = true;
            "tank/gitea" = true;
            "tank/drone" = true;
          };
          snapshotting = {
            type = "periodic";
            prefix = "zrepl_";
            interval = "15m";
          };
          pruning = {
            keep_sender = [
              { type = "not_replicated"; }
              {
                type = "grid";
                grid = "1x1h(keep=all) | 24x1h | 180x1d";
                regex = "zrepl_";
              }
            ];
            keep_receiver = [
              {
                type = "grid";
                grid = "1x1h(keep=all) | 24x1h | 30x1d | 24x30d";
                regex = "zrepl_";
              }
            ];
          };
        }
      ];
    };
  };

  systemd.services.zrepl.postStart = ''
    set -ex
    sleep 15
    chown zeta-backups /var/run/zrepl/stdinserver/zeta
    chmod go+rX /var/run/zrepl/stdinserver
    chmod go+rX /var/run/zrepl/
  '';
}

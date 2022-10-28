{ config, ... }:
{
  services.postgresqlBackup = {
    enable = true;
    startAt = "daily";
  };

  h4ck.backup.paths = [
    "/var/backup/postgresql"
    "/persist/synapse"
  ];

  services.borgbackup.jobs = {
    "zeta" = {
      inherit (config.h4ck.backup) paths;
      compression = "lz4";
      repo = "borg@zeta.rammhold.de:/tank/enc/borg/nixos.dev";
      encryption = {
        mode = "repokey";
        passCommand = "cat /var/lib/secrets/borg.password";
      };
    };
    "rsync.net" = {
      inherit (config.h4ck.backup) paths;
      compression = "lz4";
      doInit = true;
      repo = "zh1628@zh1628.rsync.net:borg/nixos.dev";
      extraArgs = "--remote-path=borg1";
      encryption = {
        mode = "repokey";
        passCommand = "cat /var/lib/secrets/borg.password";
      };
      prune.keep = {
        within = "1d";
        daily = 7;
        weekly = 1;
        monthly = -1;
      };
    };
  };
}

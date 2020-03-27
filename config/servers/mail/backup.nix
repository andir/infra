{ pkgs, config, ... }:
{
  services.borgbackup.jobs = {
    "mail" = {
      paths = map (path: if path == config.mailserver.mailDirectory then "/data/snapshots/mails" else path) config.h4ck.backup.paths;
      startAt = "hourly";
      compression = "lz4";
      repo = "borg@epsilon.rammhold.de:/home/borg/backups/mail.h4ck.space";
      encryption = {
        mode = "repokey";
        passCommand = "cat /var/lib/secrets/borg.password";
      };

      preHook = ''
        set -e
        ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r /data/mails /data/snapshots/mails
      '';
      postHook = ''
        set -e
        ${pkgs.btrfs-progs}/bin/btrfs subvolume delete /data/snapshots/mails
      '';
    };
  };
  systemd.services.borgbackup-job-mail.serviceConfig.ReadWritePaths = [ "/data/snapshots" ];
}

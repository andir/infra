{ pkgs, config, ... }:
{
  services.borgbackup.jobs = {
    "mail" = {
      environment = {
        LD_PRELOAD = "${pkgs.mimalloc}/lib/libmimalloc.so";
      };
      paths = map
        (path:
          if path == config.mailserver.mailDirectory then "/data/snapshots/mails" else
          if path == "/var/lib/dovecot/fts_xapian" then "/data/snapshots/xapian-fts" else path)
        config.h4ck.backup.paths;
      startAt = "hourly";
      compression = "lz4";
      repo = "borg@zeta.rammhold.de:/tank/enc/borg/mail.h4ck.space";
      encryption = {
        mode = "repokey";
        passCommand = "cat /var/lib/secrets/borg.password";
      };

      preHook = ''
        set -e
        ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r /data/mails /data/snapshots/mails
        ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r /data/xapian-fts /data/snapshots/xapian-fts

      '';
      postHook = ''
        set -e
        ${pkgs.btrfs-progs}/bin/btrfs subvolume delete /data/snapshots/mails
        ${pkgs.btrfs-progs}/bin/btrfs subvolume delete /data/snapshots/xapian-fts
      '';
    };
  };
  systemd.services.borgbackup-job-mail.serviceConfig.ReadWritePaths = [ "/data/snapshots" ];
}

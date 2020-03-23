{ config, ... }:
{
  services.borgbackup.jobs = {
    "mail" = {
      inherit (config.h4ck.backup) paths;
      startAt = "hourly";
      compression = "lz4";
      repo = "borg@epsilon.rammhold.de:/home/borg/backups/mail.h4ck.space";
      encryption = {
        mode = "repokey";
        passCommand = "cat /var/lib/secrets/borg.password";
      };
    };
  };
}

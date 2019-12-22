{ config, ... }:
{
  imports = [
    ../profiles/hetzner-vm.nix
  ];

  deployment = {
    targetHost = "kack.it";
    targetUser = "morph";
    substituteOnDestination = true;
  };

  networking = {
    hostName = "kack.it";
  };

  fileSystems."/".fsType = "btrfs";
  boot.initrd.luks.devices."rootfs".device = "/dev/disk/by-uuid/07586358-3815-4873-99dd-832319e71a53";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/a3316338-816b-4288-bed7-84796cfe4297";
    fsType = "ext4";
  };


  mods.hetzner = {
    networking.ipAddresses = [
      "159.69.147.18/32"
      "2a01:4f8:1c1c:4b9f::/128"
    ];
  };

  h4ck.prosody = {
    enable = true;
    serverName = "kack.it";
    adminJID = "andi@kack.it";
  };
  h4ck.syncserver.enable = true;

  services.borgbackup.jobs = {
    "kack-it" = {
      inherit (config.h4ck.backup) paths;
      compression = "lz4";
      repo = "borg@epsilon.rammhold.de:/home/borg/backups/kack-it";
      encryption = {
        mode = "repokey";
        passCommand = "cat /var/lib/secrets/borg.password";
      };
    };
  };


  system.stateVersion = "19.03";
}

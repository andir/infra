{ config, pkgs, ... }:
{
  imports = [
    ../../profiles/hetzner-vm.nix
    ../../modules/ipv6watch.nix
    ./dns.nix
    ./blog.nix
  ];

  deployment = {
    targetHost = "kack.it";
    targetUser = "morph";
    substituteOnDestination = true;

    secrets."c3shedule.env" = {
      source = "../secrets/c3schedule.env";
      destination = "/var/lib/secrets/c3schedule.env";
      owner.user = "c3schedule";
      action = ["sudo" "systemctl" "restart" "c3schedule"];
    };
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

  h4ck.ipv6watch.enable = true;
  h4ck.prosody = {
    enable = true;
    serverName = "kack.it";
    adminJID = "andi@kack.it";
  };
  h4ck.syncserver.enable = true;
  h4ck.ssh-unlock.networking.ipv6.address = "2a01:4f8:1c1c:4b9f::2/128";

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

  c3schedule = {
    # only enabled during events
    enable = false;
    config = {
      core = {
        host = "guybrush.hackint.org";
        port = 6697;
        use_ssl = "True";
        enable = "reload,c3schedule";
        logging_level = "DEBUG";
        log_raw = "True";
        auth_method = "nickserv";
        auth_username = "c3schedule";
        auth_password = "@AUTH_PASSWORD@";
        nick = "c3schedule";
        owner = "andi-";
        owner_account = "andi-";
        pid_dir = "/var/lib/c3schedule";
        homedir = "/var/lib/c3schedule";
        channels = "#36c3-schedule,#36c3-hall-a,#36c3-hall-b,#36c3-hall-c,#36c3-hall-d,#36c3-hall-a,#signalangel,#36c3-hall-e,#chaoswest-stage,#oio-stage";
        prefix = ".?";
        reply_errors = "False";
        flood_empty_wait = "0";
        flood_burst_lines = "40";
        flood_refill_rate = "30";
      };
      c3schedule = {
        channel = "#36c3-schedule";
        angel_channel = "#signalangel";
        url = "https://raw.githubusercontent.com/voc/36C3_schedule/master/everything.schedule.json";
      };
    };
  };


  system.stateVersion = "19.03";
}

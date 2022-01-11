{ config, lib, pkgs, ... }:
{
  imports = [
    ../../profiles/hetzner-vm.nix
    ../../profiles/webserver.nix
    ../../modules/ipv6watch.nix
    ./dns.nix
    ./blog.nix
    ./static.nix
    ./nixos-cloud.nix
    ./dendrite.nix
    ./synapse.nix
    ./calibre-web.nix
    ./cgit.nix
  ];

  deployment = {
    targetHost = "kack.it";
    targetUser = "morph";
    substituteOnDestination = true;

    secrets."c3shedule.env" = {
      source = "../secrets/c3schedule.env";
      destination = "/var/lib/secrets/c3schedule.env";
      owner.user = "c3schedule";
      action = [ "sudo" "systemctl" "restart" "c3schedule" ];
    };
  };

  networking = {
    hostName = "kack";
    domain = "it";
  };

  h4ck.wireguardBackbone = {
    addresses = [
      "fe80::4/64"
      #  "172.20.25.3/32"
      #  "fd21:a07e:735e:ffff::4/128"
    ];
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
    coturn.enable = true;
  };
  h4ck.syncserver.enable = true;
  h4ck.ssh-unlock.networking.ipv6.address = "2a01:4f8:1c1c:4b9f::2/128";

  services.borgbackup.jobs = {
    "kack-it" = {
      inherit (config.h4ck.backup) paths;
      compression = "lz4";
      repo = "borg@zeta.rammhold.de:/tank/enc/borg/kack.it";
      encryption = {
        mode = "repokey";
        passCommand = "cat /var/lib/secrets/borg.password";
      };
    };
  };

  c3schedule = {
    # only enabled during events
    enable = true;
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
        channels = lib.concatStringsSep "," [
          "#signal"
          # "#rc3-cbase"
          "#rc3-schedule"
          # "#rc3-one"
          # "#rc3-two"
          # "#rc3-oio"
          # "#rc3-restrealitaet"
          # "#rc3-r3s"
          # "#rc3-wikipaka"
          # "#rc3-xhain"
          # "#rc3-franconiannet"
          # "#rc3-csh"
          # "#rc3-chaostrawler"
          # "#rc3-bitwaescherei"
          # "#rc3-cwtv"
          # "#rc3-hacc"
          # "#rc3-sendezentrum"
          "#rc3-franconiannet"
          "#rc3-cwtv"
          "#rc3-aboutfuture"
          "#rc3-chaoszone"
          "#rc3-chaosstudio-hamburg"
          "#rc3-r3s"
          "#rc3-xhain"
          "#rc3-cbase"
          "#rc3-haecksen"
          "#rc3-gehacktesfromhell"
          "#rc3-sendezentrum"
          "#rc3-fem"
          "#rc3-csh"
        ];
        prefix = ".?";
        reply_errors = "False";
        flood_empty_wait = "0";
        flood_burst_lines = "40";
        flood_refill_rate = "30";
      };
      c3schedule = {
        channel = "#rc3-schedule";
        angel_channel = "#signal";
        url = "https://data.c3voc.de/rC3_21/everything.schedule.json";
        stream_url_template = "https://streaming.media.ccc.de/rc3/{{ stream_hall }}";
        session_url = "https://fahrplan.events.ccc.de/rc3/2021/Fahrplan/#{{ guid }}";
      };
    };
  };

  h4ck.publictransport = {
    enable = true;
    virtualHost = "darmstadt.io";
  };
  services.nginx.virtualHosts."darmstadt.io" = {
    enableACME = true;
    forceSSL = true;
  };

  services.grocy = {
    enable = true;
    nginx.enableSSL = true;
    hostName = "grocy.rammhold.de";
    settings = {
      currency = "EUR";
      culture = "de";
      calendar.firstDayOfWeek = 1;
    };
  };

  system.stateVersion = "19.03";
}

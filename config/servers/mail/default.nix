{ config, lib, pkgs, ... }:
let
  snms = import (import ../../../nix/sources.nix).nixos-mailserver;

  # import secrets if they exist (e.g. on deployment hosts)
  secrets =
    let
      path = ../../../secrets/mail.nix;
      default = {
        domains = [ ];
        loginAccounts = { };
      };
      exists = builtins.pathExists path;
    in
    if exists then import path else default;
in
{

  imports = [
    snms
    ../../profiles/hetzner-vm.nix
    ./backup.nix
    ./radicale
    ./roundcube.nix
  ];

  deployment = {
    targetHost = "mx.h4ck.space.";
    targetUser = "morph";
    substituteOnDestination = true;
  };

  networking = {
    hostName = "mx";
    domain = "h4ck.space";
  };

  boot.initrd.luks.devices = {
    "rootfs".device = "/dev/disk/by-uuid/f7f8b86e-c0c4-42a1-b4ff-8e90a3c2b72d";
    "data".device = "/dev/disk/by-uuid/da233a8f-129d-404b-a217-586594896276";
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/7f183a7b-354d-46c8-a1df-e83f80b327cf";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/4dcdc263-6c8e-456d-a79f-6e19a6168cee";
      fsType = "ext4";
    };
    "/data" = {
      device = "/dev/disk/by-uuid/becf89e2-1b70-4db2-accf-184e466a035e";
      fsType = "btrfs";
      options = [ "compress=zstd" ];
    };
    "${config.mailserver.mailDirectory}" = {
      fsType = "none";
      options = [ "bind" ];
      device = "/data/mails";
    };
    "${config.mailserver.dkimKeyDirectory}" = {
      fsType = "none";
      options = [ "bind" ];
      device = "/data/dkim";
    };
    "/var/sieve" = {
      fsType = "none";
      options = [ "bind" ];
      device = "/data/sieve";
    };
    "/var/lib/radicale" = {
      fsType = "none";
      options = [ "bind" ];
      device = "/data/radicale";
    };
  };

  mods.hetzner = {
    networking.ipAddresses = [
      "159.69.146.50/32"
      "2a01:4f8:1c1c:f2f5::/128"
    ];
  };
  h4ck.ssh-unlock.networking.ipv6.address = "2a01:4f8:1c1c:f2f5::2/128";

  # snms provides kresd configuration, pull this in when that isn't the case (anymore?)
  services.unbound.enable = !config.services.kresd.enable;

  h4ck.backup.paths = [
    config.mailserver.mailDirectory
    config.mailserver.dkimKeyDirectory
    "/var/sieve" # managesieve files
    "/var/lib/radicale" # radicale files (contacts, calendar, …)
  ];

  # monitor that all the configured domains have a "valid" MX record
  # I lost some entries in the pase due to slight differences in bind vs knot
  # zone interpretation when more specific records in the same file exist
  h4ck.monitoring.dns = (
    lib.listToAttrs (
      map
        (
          domain:
          lib.nameValuePair domain {
            queryType = "MX";
          }
        )
        config.mailserver.domains
    )
  )
  # also ensure that all the domains have valid domainkeys set otherwise DKIM
  # validation fails
  // (
    lib.listToAttrs (
      map
        (
          domain:
          lib.nameValuePair "mail._domainkey.${domain}" {
            queryType = "TXT";
          }
        )
        config.mailserver.domains
    )
  );

  security.acme.certs."mx.h4ck.space".keyType = "rsa4096";

  mailserver = {
    enable = true;
    fqdn = "mx.h4ck.space";
    domains = [
      "kack.it"
    ] ++ secrets.domains;
    loginAccounts = {
      "andi@kack.it" = {
        hashedPassword = "$6$oJhcZDZZ$9QFwPXZhmjPjJL0TcEsZVTehhdWFxxjVDBDg0Ked71ziAd1GnsJJUpsuIhqG8fdAhalQe/BXn8VZE4Te7oE7g/";

        aliases = [
          "test@kack.it"
        ];
      };
    } // secrets.loginAccounts;

    # Use Let's Encrypt certificates. Note that this needs to set up a stripped
    # down nginx and opens port 80.
    certificateScheme = 3;

    # Enable IMAP and POP3
    enableImap = true;
    enablePop3 = false;
    enableImapSsl = true;
    enablePop3Ssl = false;

    # Enable the ManageSieve protocol
    enableManageSieve = true;

    # whether to scan inbound emails for viruses (note that this requires at least
    # 1 Gb RAM for the server. Without virus scanning 256 MB RAM should be plenty)
    virusScanning = true;
  };
  services.dovecot2.mailPlugins.globally.enable = [ "zlib" ];
  services.dovecot2.extraConfig = ''
    mail_cache_max_size = 10M # tame the stupid index rewriting code on large inboxes
    service imap {
      vsz_limit = 512MB
    }
    service lmtp {
      vsz_limit = 368MB
      process_limit = 10
    }
    # Zlib compression might have been an issue with isync where it would
    # timeout because dovecot is still waiting for data while mbsync thought it
    # is done.
    # protocol imap {
    #   mail_plugins = $mail_plugins imap_zlib
    # }

    plugin {
      zlib_save_level = 6
      zlib_save = gz
    }
  '';
  services.postfix.config = {
    lmtp_destination_concurrency_limit = "10";
    smtpd_recipient_restrictions = lib.mkBefore [
      "check_recipient_access pcre:${builtins.toFile "inject-x-original-to.pcre" "/(.+)/  prepend X-Original-To: $1"}"
    ];
  };
}

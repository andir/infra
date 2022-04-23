{ pkgs, config, lib, ... }:
let
  sources = import ../../../nix/sources.nix;
in
{
  imports = [
    ../../profiles/hetzner-vm.nix
    (sources.nixos-security-tracker + "/module.nix")
    ./rtmp.nix
  ];

  h4ck.wireguardBackbone = {
    addresses = [
      "fe80::3/64"
      #  "172.20.25.2/32"
      #  "fd21:a07e:735e:ffff::3/128"
    ];
    peers = {
      ranzbook = {
        localAddresses = [ "fe80::1/64" ];
        remoteAddresses = [ "fe80::2/64" ];

        mtu = 1420;
        babel = true;

        localPort = 42421;
        remotePort = 42421;
        remotePublicKey = "92y41GtkPs1Ul1lSBV1yaBHmZmaMMbf9JthN/wlS2V8=";
      };
    };
  };
  networking.firewall.allowedUDPPorts = [ 11001 11002 ];

  deployment = {
    targetHost = "iota.h4ck.space";
    targetUser = "morph";
    substituteOnDestination = true;

    secrets."gitlab-runner.env" = {
      source = "../secrets/gitlab-runner.env";
      destination = "/var/secrets/gitlab-runner.env";
      owner.user = "gitlab-runner";
      action = [ "sudo" "systemctl" "restart" "gitlab-runner2" ];
    };
  };

  mods.hetzner = {
    networking.ipAddresses = [
      "95.216.155.219/32"
      "2a01:4f9:c010:593::/128"
    ];
  };

  networking = {
    hostName = "iota";
    domain = "h4ck.space";
  };

  services.gitlab-runner = {
    enable = true;
    package = pkgs.unstable.gitlab-runner;
    services = {
      # runner for building in docker via host's nix-daemon
      # nix store will be readable in runner, might be insecure
      nix = {
        # File should contain at least these two variables:
        # `CI_SERVER_URL`
        # `REGISTRATION_TOKEN`
        registrationConfigFile = "/var/secrets/gitlab-runner.env";
        dockerImage = "alpine";
        dockerVolumes = [
          "/nix/store:/nix/store:ro"
          "/nix/var/nix/db:/nix/var/nix/db:ro"
          "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket:ro"
        ];
        dockerDisableCache = true;
        preBuildScript = pkgs.writeScript "setup-container" ''
          mkdir -p -m 0755 /nix/var/log/nix/drvs
          mkdir -p -m 0755 /nix/var/nix/gcroots
          mkdir -p -m 0755 /nix/var/nix/profiles
          mkdir -p -m 0755 /nix/var/nix/temproots
          mkdir -p -m 0755 /nix/var/nix/userpool
          mkdir -p -m 1777 /nix/var/nix/gcroots/per-user
          mkdir -p -m 1777 /nix/var/nix/profiles/per-user
          mkdir -p -m 0755 /nix/var/nix/profiles/per-user/root
          mkdir -p -m 0700 "$HOME/.nix-defexpr"

          . ${pkgs.nix}/etc/profile.d/nix.sh

          ${pkgs.nix}/bin/nix-env -i ${lib.concatStringsSep " " (with pkgs; [ nix cacert git openssh ])}
        '';
        environmentVariables = {
          ENV = "/etc/profile";
          USER = "root";
          NIX_REMOTE = "daemon";
          PATH = "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin";
          NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
        };
        tagList = [ "nix" "docker" ];
        runUntagged = true;
      };
    };
  };

  services.k3s = {
    enable = false;
    docker = true;
    role = "server";
    package = pkgs.unstable.k3s;
  };

  systemd.network.networks."99-main".enable = false;

  system.stateVersion = "19.03";


  # iota.h4ck.space
  # v6 net block:
  #  - fd42:4242:4201::/48
  h4ck.dn42 = {
    enable = true;
    bgp = {
      asn = 4242423991;
      staticRoutes = {
        ipv4 = [
          #          "172.20.24.0/23"
          "172.20.25.0/25"
          "172.20.199.0/24"
        ];
        ipv6 = [
          "fd42:4242:4200::/40"
          #          "fd21:a07e:735e::/48"
        ];
      };
    };
    peers = {
      bertha = {
        interfaceName = "wg-bertha";
        tunnelType = null;
        bgp = {
          asn = 4242423991;
          ipv4.gateway_recursive = true;
          ipv4.next_hop_address = "172.20.25.2";
          ipv4.extended_next_hop = true;
        };
        addresses = {
          ipv6.remote_address = "fe80::1";
          ipv6.local_address = "fe80::3";
          ipv6.prefix_length = 64;
        };
      };
      kappa = {
        interfaceName = "wg-kappa";
        tunnelType = null;
        bgp = {
          asn = 4242423991;
          ipv4.gateway_recursive = true;
          #ipv4.next_hop_address = "172.20.25.2";
          ipv4.extended_next_hop = true;
        };
        addresses = {
          ipv6.remote_address = "fe80::12";
          ipv6.local_address = "fe80::3";
          ipv6.prefix_length = 64;
        };
      };
      flokli = {
        tunnelType = "wireguard";
        mtu = 1420;
        wireguardConfig = {
          localPort = 42018;
          remoteEndpoint = null;
          remotePublicKey = "CH/IzXS1DdX52RpiD5Qo71W3soubTH6kIqJqdYID7R0=";
        };
        bgp = {
          asn = 4242422100;
          local_pref = 100;
          announce = "all";
          ipv6.extended_next_hop = true;
          ipv4.extended_next_hop = true;
          ipv4.gateway_recursive = false;
        };
        addresses = {
          ipv6 = {
            local_address = "fe80::1";
            remote_address = "fe80::2";
            prefix_length = 64;
          };
        };
      };

      cloudfiles_at = {
        tunnelType = "wireguard";
        mtu = 1420;
        wireguardConfig = {
          localPort = 42001;
          remotePort = 42001;
          remoteEndpoint = "2a01:4f8:c010:2346::2";
          remotePublicKey = "OewZmkZsgKKOl//GEI0Ntudy98L/K0mKET7N+zdiJiY=";
        };
        bgp = {
          asn = 4242423348;
          local_pref = 100;
        };
        addresses = {
          ipv4.local_address = "172.20.255.233";
          ipv6.local_address = "fd42:4242:4201::1";
          ipv4.remote_address = "172.20.33.49";
          ipv6.remote_address = "fd00:4242:3348:65:3::1";
        };
      };

      lss233 = {
        tunnelType = "wireguard";
        mtu = 1420;
        wireguardConfig = {
          localPort = 42028;
          remotePort = 53991;
          remoteEndpoint = "lux.n.lss233.com";
          remotePublicKey = "2hVHLTlQtH90qtLOHD9Yx35OpR08o46fcwa7PgeF+Wk=";
        };
        bgp = {
          asn = 4242421826;
          local_pref = 100;
        };
        addresses = {
          ipv6.local_address = "fe80::1";
          ipv6.remote_address = "fe80::1826";
        };
      };

      jlu5 = {
        tunnelType = "wireguard";
        mtu = 1420;
        wireguardConfig = {
          localPort = 42029;
          remotePort = 53991;
          remoteEndpoint = "dn42-uk-lon01.jlu5.com";
          remotePublicKey = "pEQZQOD67QeWXqrHLrMoCXug/cOXJFMXH5vwQ1cW70s=";
        };
        bgp = {
          asn = 4242421080;
          local_pref = 100;
          ipv4.gateway_recursive = false;
          ipv4.extended_next_hop = true;
        };

        addresses = {
          ipv6.local_address = "fe80::1";
          ipv6.remote_address = "fe80::116";
        };
      };

      yura = {
        tunnelType = "wireguard";
        mtu = 1420;
        wireguardConfig = {
          localPort = 42030;
          remotePort = 23991;
          remoteEndpoint = "llix.dneo.moeternet.com";
          remotePublicKey = "3egMh/fpa/+YTAfIXihtNYTReh27AaS53WJyp7UT/Qg=";
        };
        bgp = {
          asn = 4242422464;
          local_pref = 100;
          ipv4.gateway_recursive = false;
          ipv4.extended_next_hop = true;
        };

        addresses = {
          ipv6.local_address = "fe80::1";
          ipv6.remote_address = "fe80::2464";
        };
      };

      #moecast = {
      #  tunnelType = "wireguard";
      #  mtu = 1408;
      #  wireguarConfig = {
      #    localPort = 42031;
      #    remotePort = 53991; # FIXME: change to agreed on port
      #  };
      #};

      kn = {
        tunnelType = "wireguard";
        mtu = 1408;
        wireguardConfig = {
          localPort = 42016;
          remotePort = 42016;
          remoteEndpoint = "t4-2.high5.nl";
          remotePublicKey = "I13hQ9ylXn/xroWgNKOf98r6itlQbd0jX/7w63dfIxM=";
        };
        bgp = {
          asn = 4242421239;
          local_pref = 100;
        };
        addresses = {
          ipv6 = {
            local_address = "fdfd:3ba:342d:a7d1::1";
            remote_address = "fdfd:3ba:342d:a7d1::";
            prefix_length = 127;
          };
        };
      };
      cccda = {
        tunnelType = "wireguard";
        mtu = 1420;
        wireguardConfig = {
          localPort = 43025;
          remoteEndpoint = "core1.darmstadt.ccc.de";
          remotePort = 43025;
          remotePublicKey = "iB8P2uuKGISflakJiHMGuBR7zKK44qx+ioqeBN0sEnk=";
        };
        bgp = {
          accept = "all";
          asn = 4242420101;
          local_pref = 100;
          multi_protocol = false;
          export_additional_asns = [
            4242422100
          ];
        };

        addresses = {
          ipv4.local_address = "172.20.255.237";
          ipv4.remote_address = "172.20.255.238";
          ipv4.prefix_length = 30;
          ipv6.local_address = "fe80::f00";
          ipv6.remote_address = "fe80::ccc:da";
          ipv6.prefix_length = 64;
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  services.nginx = {
    enable = true;
    virtualHosts."iota.h4ck.space" = {
      enableACME = true;
      forceSSL = true;
    };
  };
  mods.hetzner.vm.persistentDisks."/persist/postgresql".id = 11409641;
  fileSystems."/var/lib/postgresql" = {
    fsType = "none";
    options = [ "bind" ];
    device = "/persist/postgresql/postgresql";
  };
  services.nixos-security-tracker = {
    enable = true;
    virtualHost = "iota.h4ck.space";
    database = "postgresql";
    #githubEventsSharedSecretFile = "/var/lib/nixos-security-tracker/github-events-secret";
    # useMemcached = true;
  };
  # services.borgbackup.jobs = {
  #   "nixos-security-tracker" = {
  #     paths = [ "/var/backup/nixos-security-tracker" ];
  #     startAt = "daily";
  #     compression=  "lz4";
  #     repo = "borg@zeta.rammhold.de:/tank/enc/borg/nixos-security-tracker";
  #     encryption.mode = "none";
  #     preHook = ''
  #       /run/wrappers/bin/su -c '${config.services.postgresql.package}/bin/pg_dump nixos-security-tracker' nixos-security-tracker | ${pkgs.gzip}/bin/gzip -C > /var/backup/nixos-security-tracker/postgresql-all.sql.gz
  #     '';
  #     postHook = ''
  #       ${pkgs.coreutils}/bin/rm /var/backup/nixos-security-tracker/postgresql-all.sql.gz
  #     '';
  #   };
  # };

  systemd.tmpfiles.rules = [ "d /var/backups/nixos-security-tracker 0700 postgres - - -" ];

  systemd.services.tmate = lib.mkIf false {
    # FIXME: This is currently complaining about not running as root while
    #        trying to init the "jail" and likely otherwise would just work.
    # Usage:
    # $ ssh-keygen -l -f ~/.ssh/known_hosts  | grep tmate.h4ck.space
    # SHA256:5U7MF7nnBrIETnZGlGanooGmqdNw4HuD5ztMwROGOh0 [tmate.h4ck.space]:2222,[95.216.155.219]:2222 (ED25519)
    # $ cat - > ~/.tmate.conf <<EOF
    # set -g tmate-server-host "tmate.h4ck.space"
    # set -g tmate-server-port 2222
    # set -g tmate-server-ed25519-fingerprint "SHA256:5U7MF7nnBrIETnZGlGanooGmqdNw4HuD5ztMwROGOh0"
    # EOF
    # nix-shell -p tmate --run "tmate -F"
    enable = false;
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    preStart = ''
      cd $STATE_DIRECTORY
      test -e $STATE_DIRECTORY/ssh_host_ed25519_key || ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f $STATE_DIRECTORY/ssh_host_ed25519_key
    '';
    script = ''
      ${pkgs.tmate-ssh-server}/bin/tmate-ssh-server -p 2222 -h tmate.h4ck.space -k $STATE_DIRECTORY/
    '';
    serviceConfig = {
      DynamicUser = true;
      RuntimeDirectory = "tmate";
      StateDirectory = "tmate";
    };
  };
}

{
  imports = [
    ../profiles/hetzner-vm.nix
  ];
  h4ck.wireguardBackbone = {
    addresses = [
      "fe80::3/64"
      "172.20.25.2/32"
      "fd21:a07e:735e:ffff::3/128"
    ];
  };
  networking.firewall.allowedUDPPorts = [ 11001 11002 ];

  deployment = {
    targetHost = "95.216.155.219";
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

  # FIXME: this host needs a proper DNS rentry
  h4ck.monitoring.targetHost = "95.216.155.219";

  services.gitlab-runner2 = {
    enable = true;
    registrationConfigFile = "/var/secrets/gitlab-runner.env";
  };


  systemd.network.networks."99-main".enable = false;

  system.stateVersion = "19.03";


  h4ck.dn42 = {
    enable = true;
    bgp = {
      asn = 4242423991;
      staticRoutes = {
        ipv4 = [
          "172.20.24.0/23"
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
        wireguardConfig = {
          localPort = 43025;
          remoteEndpoint = "core1.darmstadt.ccc.de";
          remotePort = 43025;
          remotePublicKey = "iB8P2uuKGISflakJiHMGuBR7zKK44qx+ioqeBN0sEnk=";
        };
        bgp = {
          asn = 123;
          local_pref = 100;
        };

        addresses = {
          ipv4.local_address = "172.20.255.237";
          ipv4.remote_address = "172.20.255.238";
          ipv6.local_address = "fe80::f00";
          ipv6.remote_address = "fe80::ccc:da";
        };
      };
    };
  };

}

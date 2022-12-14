{ pkgs, lib, ... }:
{

  imports = [
    ../../profiles/server.nix
    ./hardware.nix
    ./wan-party.nix
  ];

  deployment = {
    targetHost = "kappa.h4ck.space";
    targetUser = "morph";
  };

  networking = {
    hostName = "kappa";
    domain = "h4ck.space";
  };

  networking.useNetworkd = true;
  networking.useDHCP = false;
  systemd.network.networks."20-uplink" = {
    matchConfig = {
      Name = "ens3";
    };
    addresses = [
      { addressConfig.Address = "92.60.37.85/22"; }
      { addressConfig.Address = "2a03:4000:33:792::/128"; }
    ];

    gateway = [
      "fe80::1"
      "92.60.36.1"
    ];
  };

  boot.kernel.sysctl."net.ipv6.default.forwarding" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  h4ck.dn42 = {
    enable = true;
    bgp = {
      asn = 4242423991;
      staticRoutes = {
        ipv4 = [
          "172.20.24.0/23"
          #"172.20.25.0/25"
          "172.20.199.0/24"
        ];
        ipv6 = [
          "fd42:4242::/40"
          "fd21:a07e:735e::/48"
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
          #ipv4.next_hop_address = "172.20.25.2";
          ipv4.extended_next_hop = true;
        };
        addresses = {
          ipv6.remote_address = "fe80::1";
          ipv6.local_address = "fe80::12";
          ipv6.prefix_length = 64;
        };
      };
      iota = {
        interfaceName = "wg-iota";
        tunnelType = null;
        bgp = {
          asn = 4242423991;
          ipv4.gateway_recursive = true;
          #ipv4.next_hop_address = "172.20.25.2";
          ipv4.extended_next_hop = true;
        };
        addresses = {
          ipv6.remote_address = "fe80::3";
          ipv6.local_address = "fe80::12";
          ipv6.prefix_length = 64;
        };
      };

    };
  };

  h4ck.wireguardBackbone = {
    addresses = [
      "fe80::12/64"
    ];

    peers = {
      kif = {
        localAddresses = [ "fe80::1/64" ];
        remoteAddresses = [ "fdde:953a:0e14::/48" ];
        mtu = 1420;
        babel = false;

        remotePublicKey = "2iF9WFNJBlEHLdjcnMUJzGOHq0kHytrpfOUTeJPD5QU=";
        remotePort = 22094;
        localPort = 22094;
        remoteEndpoint = "kif.gsc.io";
        pskFile = "/var/lib/secrets/kif-psk";
      };

      haos = {
        localAddresses = [ "172.20.25.12/32" ];
        remoteAddresses = [ "172.20.25.50/32" "192.168.2.123/32" ];
        localPort = 42255;
        mtu = 1400;
        babel = false;
        remotePublicKey = "B92lDGh2rMnFKDR1OeyjbvyQvbPtogDwRG/ACyJX8QY=";
        remotePort = 42255;
      };

      pixel4 = {
        localPort = 42256;
        localAddresses = [
          "172.20.25.12/32"
          "fd21:a07e:735e:0f01::1/64"
        ];
        remoteAddresses = [
          "172.20.25.51/32"
          "fd21:a07e:735e:0f01::2/64"
        ];
        babel = false;
        remotePublicKey = "66r6LlBeU79xxzNKH1T1QSBpiYTXedSUpzN4Zbye3jM=";
        mtu = 1400;
      };

      gamma = {
        localPort = 42257;
        localAddresses = [
          "172.20.25.12/32"
          "fd21:a07e:735e:0f02::1/64"
        ];
        remoteAddresses = [
          "172.20.25.52/32"
          "fd21:a07e:735e:0f02::2/64"
        ];
        babel = false;
        remotePublicKey = "FtSoOFYtUgO+R7xHBs3OkBV0aRrR70ddxCrN4AYEty0=";
        mtu = 1400;
      };


      origen = {
        localPort = 42258;
        localAddresses = [
          "172.20.25.12/32"
          "fd21:a07e:735e:0f03::1/64"
        ];
        remoteAddresses = [
          "172.20.25.53/32"
          "fd21:a07e:735e:0f03::2/64"
        ];
        babel = false;
        remotePublicKey = "zLMDAz+OAEAyY6cQnP6SWudbNLaYuFnR2Vm1h3+hI3s=";
        mtu = 1400;
      };
      delta = {
        localPort = 42259;
        localAddresses = [
          "172.20.25.12/32"
          "fd21:a07e:735e:0f04::1/64"
        ];
        remoteAddresses = [
          "172.20.25.54/32"
          "fd21:a07e:735e:0f04::2/64"
        ];
        babel = false;
        remotePublicKey = "qHAN1RKOVvQGp5wBuxmhUgqTLP0qdE1R+kuSFigSayE=";
        mtu = 1400;
      };

    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/secrets 700 'systemd-network' root - -"
  ];

  h4ck.authorative-dns = {
    enable = true;
    verbose = true;
    listenAddresses = [
      "92.60.37.85@53"
      "2a03:4000:33:792::@53"
    ];
    slaveZones = lib.listToAttrs (map
      (zone: lib.nameValuePair zone
        {
          masters = [
            "159.69.147.18"
            "2a01:4f8:1c1c:4b9f::"
          ];
        }) [
      "darmstadt.digital"
      "darmstadt.io"
      "kack.it"
      "megfau.lt"
      "nopejs.io"
      "notmuch.email"
      "wifi-darmstadt.de"
      "wlanladadi.net"
      "nixos.cloud"
    ]);
  };

  system.stateVersion = "20.09";
}

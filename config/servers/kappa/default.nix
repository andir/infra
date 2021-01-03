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

{ pkgs, lib, ... }:
{

  imports = [
    ../../profiles/server.nix
    ./hardware.nix
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

    ]);
  };

  system.stateVersion = "20.09";
}

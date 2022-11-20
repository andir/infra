{ lib, ... }:
{
  h4ck.authorative-dns = {
    enable = true;
    verbose = true;
    listenAddresses = [
      "159.69.147.18@53"
      "2a01:4f8:1c1c:4b9f::@53"
    ];
    authZones =
      lib.listToAttrs
        (
          map
            (
              name: lib.nameValuePair "${name}" {
                zoneFile = ./zones + "/${name}";
                slaves = {
                  "ns2.h4ck.space-v4" = {
                    address = "72.60.37.85";
                  };
                  "ns2.h4ck.space-v6" = {
                    address = "2a03:4000:33:792::";
                  };
                };
              }
            ) [
            "darmstadt.digital"
            "darmstadt.io"
            "kack.it"
            "nopejs.io"
            "notmuch.email"
            "wifi-darmstadt.de"
            "wlanladadi.net"
            "nixos.cloud"
          ]
        ) // {
        "megfau.lt" = {
          zoneFile = ./zones + "/megfau.lt";
          slaves = {
            "ns2.h4ck.space-v4" = {
              address = "72.60.37.85";
            };
            "ns2.h4ck.space-v6" = {
              address = "2a03:4000:33:792::";
            };
          };
        };
      };
    slaveZones = lib.listToAttrs (
      map
        (
          name: lib.nameValuePair "${name}" {
            masters = [
              "130.83.198.3"
              "2001:41b8:83f:4242::c603"
            ];
            dnssecSigning = false;
          }
        ) [
        "c-radar.de"
        "c-radar.ccc.de"
        "cdark.net"
        "chaos-darmstadt.de"
        "darmstadt.ccc.de"
        "darmstadt.macht.schule"
        "digitales-ehrenamt.jetzt"
        "hessen.macht.schule"
        "hessentrojaner.de"
        "metarheinmain.de"
        "w17.io"
        "hackint.org"
        "hackint.eu"
      ]
    );
  };


}

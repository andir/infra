{
  imports = [
    ../../profiles/server.nix
    ./hardware-config.nix
    ./network.nix
  ];

  deployment = {
    targetHost = "omicron.h4ck.space";
    targetUser = "morph";
    substituteOnDestination = false;
  };

  networking = {
    hostName = "omicron";
    domain = "h4ck.space";
  };

  h4ck.monitoring.targetHost = "172.20.25.64";

  h4ck.wireguardBackbone = {
    addresses = [
      "fe80::64/64"
    ];
  };

  system.stateVersion = "21.11";
}


{
  imports = [
    ../../profiles/server.nix
    ./hardware-config.nix
    ./network.nix
    ./gitea.nix
    ./drone.nix
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

  users.users.hydra = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ092Wisz8hx04SdvHEMbfWMNuiUTkxDtAcJv9RwO3eT hydra-queue-runner@zeta"
    ];
    group = "hydra";
  };
  users.groups.hydra = { };
  nix.trustedUsers = [ "hydra" ];

  system.stateVersion = "21.11";
}


{ pkgs, config, ... }:
{
  imports = [
    ../../profiles/server.nix
    ./hardware-config.nix
    ./network.nix
    ./gitea.nix
    ./drone.nix
    ./vaultwarden.nix
    ./backups.nix
    #./gotosocial.nix
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

  users.users.ana = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ66kAZEp/oC+rurNhfGHvQZVh0zBI6ZwVLuc5KiQrwY"
    ];
    group = "users";
    packages = [ pkgs.borgbackup ];
  };

  system.stateVersion = "21.11";


  services.nginx.virtualHosts.${"blueagate" + ".cy" + "sec.de"} = {
    enableACME = true;
    forceSSL = true;
    default = true;
    locations."/".root = pkgs.runCommand "empty" { } "mkdir $out";
  };

  services.nginx.virtualHosts."gts.kack.it" = {
    enableACME = true;
    forceSSL = true;
    locations."/".root = pkgs.runCommand "empty" { } "mkdir $out";
  };
}

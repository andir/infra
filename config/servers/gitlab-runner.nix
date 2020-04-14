{
  imports = [
    ../profiles/hetzner-vm.nix
    ../modules/wireguard.nix
  ];
  h4ck.wireguardBackbone = {
    addresses = [
      "fe80::3/64"
      "172.20.25.2/32"
      "fd21:a07e:735e:ffff::3/128"
    ];
    peers = {
      "mon" = {
        localPort = 11001;
        remotePublicKey = "SSywq3RQZqQDOBDNBIliVxTXVaOGwCPBpGkzZtvuSU8=";
        remoteEndpoint = "mon.h4ck.space";
      };
      "bertha" = {
        localPort = 11002;
        remotePublicKey = "6A8qvwQnxOqo8EPntT7VmoR6PVUI7fHhE6zs8P7rVGk=";
      };
    };
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
      action = ["sudo" "systemctl" "restart" "gitlab-runner2"];
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
}

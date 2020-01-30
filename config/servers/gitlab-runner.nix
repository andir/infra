{
  imports = [
    ../profiles/hetzner-vm.nix
  ];

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

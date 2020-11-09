{ config, pkgs, lib, ... }:
{
  imports = [
    ../../profiles/server.nix
    ./hardware.nix
  ];

  deployment = {
    targetHost = "fd21:a07e:735e:ff01:ba27:ebff:fecb:b5da";
    targetUser = "root";
    substituteOnDestination = false; # TODO: is this faster?
  };
  h4ck.monitoring.targetHost = config.deployment.targetHost;

  hardware.pulseaudio = {
    enable = true;
    systemWide = true;
    package = pkgs.pulseaudioFull;
    zeroconf.publish.enable = true;
    tcp = {
      enable = true;
      anonymousClients.allowAll = true;
    };
  };

}

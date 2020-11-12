{ config, pkgs, lib, ... }:
{
  imports = [
    ../../profiles/server.nix
    ./hardware.nix
  ];

  deployment = {
    targetHost = "10.250.11.121";
    targetUser = "morph";
    substituteOnDestination = false; # TODO: is this faster?
  };
  h4ck.monitoring.targetHost = config.deployment.targetHost;

  sound.enable = true;
  hardware.pulseaudio = {
    enable = true;
    systemWide = true;
    package = pkgs.pulseaudioFull;
    zeroconf.publish.enable = true;
    tcp = {
      enable = true;
      anonymousClients.allowAll = true;
    };
    extraConfig = ''
      # unload-module module-udev-detect
      # load-module module-udev-detect tsched=0
      # load the unix socket module without auth requirement
      unload-module module-native-protocol-unix
      load-module module-native-protocol-unix auth-anonymous=1
    '';
  };
  services.spotifyd = {
    enable = true;
    config = ''
      [global]
      zeroconf_port = 5354
      device_name = crappy
      backend = pulseaudio
      bitrate = 320
    '';
  };

  networking.firewall.allowedTCPPorts = [
    4713 # pulseaudio
    5353 # avahi
    5354 # zeroconf spotifyd
  ];

  networking.firewall.allowedUDPPorts = [
    4713 # pulseaudio
    5353 # avahi
    5354 # zeroconf spotifyd
  ];

  environment.systemPackages = with pkgs; [
    mpv
    youtube-dl
    raspberrypi-tools
  ];
}

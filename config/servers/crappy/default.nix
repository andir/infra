{ config, pkgs, lib, ... }:
{
  imports = [
    ../../profiles/server.nix
    ./hardware.nix
    ./graphical.nix
    ./zigbee.nix
    ./hass
    ./snapcast.nix
  ];

  deployment = {
    targetHost = "172.20.24.67";
    targetUser = "morph";
    substituteOnDestination = false; # TODO: is this faster?

    secrets."home-assistant-secrets.yml" = {
      source = toString ../../../secrets/home-assistant-secrets.yaml;
      destination = "/var/lib/hass/secrets.yaml";
      permissions = "0400";
      owner = {
        user = "hass";
        group = "hass";
      };
      action = [ "sudo" "systemctl" "restart" "home-assistant" ];
    };
  };
  h4ck.monitoring.targetHost = config.deployment.targetHost;

  sound.enable = true;

  # do not create the home dir for the pulse user as otherwise
  # the permissions will be 700 and nobody else on the system
  # is able to access the daemon files *after* the activation
  # script has been run.
  users.users.pulse.createHome = lib.mkForce false;
  systemd.tmpfiles.rules = [
    "d '/run/pulse' 0755 pulse pulse"
  ];
  hardware.pulseaudio = {
    enable = true;
    systemWide = true;
    package = pkgs.pulseaudioFull;
    extraModules = [ ];
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
      device_name = "crappy"
      backend = "pulseaudio"
      bitrate = 320
    '';
  };

  services.mopidy = {
    enable = true;
    extensionPackages = with pkgs; [
      mopidy-mpd
      mopidy-iris
      mopidy-local
      mopidy-somafm
      mopidy-tunein
    ];
    configuration = ''
      [http]
      enabled = true
      hostname = 127.0.0.1
      port = 6680
      [audio]
      output = audioresample ! audio/x-raw,rate=48000,channels=2,format=S16LE ! audioconvert ! wavenc ! filesink location=/run/snapserver/mopidy
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
    #rockpi4.mpv
    mpv
    youtube-dl
    #rockpi4.mpp
    #rockpi4.ffmpeg
    ffmpeg
    syncplay
    streamlink

    ncmpcpp
  ];

  hardware.opengl.enable = true;
}

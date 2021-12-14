{ config, pkgs, lib, ... }:
{
  imports = [
    ../../profiles/server.nix
    ./hardware.nix
    ./graphical.nix
    ./zigbee.nix
  ];

  deployment = {
    targetHost = "172.20.24.67";
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
      device_name = "crappy"
      backend = "pulseaudio"
      bitrate = 320
    '';
  };

  services.home-assistant = {
    enable = true;
    package = (pkgs.home-assistant.override {
      extraComponents = [
        "frontend"
        "esphome"
        "met"
        "mqtt"
        "spotify"
        "wled"
        "rmvtransport"
        "denonavr"
        "kodi"
      ];
    }).overrideAttrs (_: {
      doInstallCheck = false;
    });
    lovelaceConfig = {
      title = "Home";
      views = [
        {
          title = "Transport";
          cards = [
            {
              title = "DA TZ Rhein-Main";
              type = "custom:rmv-card";
              entity = [
                "sensor.darmstadt_tz_rhein_main"
              ];
            }
            {
              title = "DA Hbf";
              type = "custom:rmv-card";
              entity = [
                "sensor.darmstadt_hauptbahnhof"
              ];
            }
          ];
        }
        {
          title = "Media";
          cards = [
            {
              type = "custom:mini-media-player";
              title = "Amplifier";
              entity = "media_player.denon";
            }
          ];
        }
      ];
    };
    config = {
      default_config = { };
      lovelace = {
        mode = "yaml";
        resources = lib.traceVal pkgs.lovelaceModules.allResources.resources;
      };
      homeassistant = {
        name = "Home";
        unit_system = "metric";
        currency = "EUR";
        auth_providers = [
          {
            type = "trusted_networks";
            allow_bypass_login = true;
            trusted_networks = [
              "fd21:a07e:735e::/48"
              "172.20.24.0/24"
            ];
          }
          {
            type = "homeassistant";
          }
        ];
      };
      http = {
        server_host = "::1";
        trusted_proxies = [ "::1" ];
        use_x_forwarded_for = true;
      };
      mqtt = {
        broker = "10.250.43.1";
        discovery = true;
      };
      automation = {
        "Turn off the music" = {
          trigger = [
            {
              platform = "time";
              at = "03:00:00";
            }
          ];
          condition = [ ];
          action = [
            {
              service = "media_player.turn_off";
              target.entity_id = "media_player.denon";
            }
          ];
        };
      };

      sensor = [
        {
          platform = "rmvtransport";
          next_departure = [
            {
              # TZ Rhein-Main
              station = "3024456";
              time_offset = 5;
              destinations = [
                "Darmstadt Luisenplatz"
                "Darmstadt-Kranichstein Bordsdorffstrasse"
              ];
            }
          ];
        }
        {
          platform = "rmvtransport";
          next_departure = [
            {
              # DA Hbf
              station = "3004734";
              time_offset = 5;
              destinations = [
                "Darmstadt Luisenplatz"
                "Darmstadt-Kranichstein Bordsdorffstrasse"
                "Weinheim"
              ];
            }
          ];
        }
      ];
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."home.rammhold.de" = {
      default = true;
      locations."/nix-resources/".alias = (toString pkgs.lovelaceModules.allResources.wwwRoot) + "/";
      locations."/" = {
        proxyPass = "http://[::1]:8123";
        proxyWebsockets = true;
      };
      extraConfig = ''
        allow 127.0.0.0/8;
        allow ::1/128;
        allow 172.20.24.0/24;
        allow fd21:a07e:735e::/48;
        deny all;
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [
    4713 # pulseaudio
    5353 # avahi
    5354 # zeroconf spotifyd
    80
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
  ];

  hardware.opengl.enable = true;
}

{ pkgs, ... }:
let
  mkSnapClient = name': device:
    let
      name = "snapclient-${builtins.replaceStrings [" "] [""] name'}";
    in
    {
      systemd.services.${name} = {
        after = [ "snapserver.service" "pulseaudio.service" ];
        wants = [ "pulseaudi.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.snapcast ];
        script = ''
          exec snapclient --hostID '${name'}' --host 127.0.0.1 --player pulse --soundcard='${device}'
        '';
        environment.HOME = "%t/${name}";
        serviceConfig = {
          DynamicUser = true;
          RuntimeDirectory = name;
          WorkingDirectory = "%t/${name}";
          User = name;
          Group = name;
          PrivateTmp = true;
          ProtectHome = true;
          PrivateMounts = true;
          PrivateDevices = true;
        };
      };
    };
in
{
  services.snapserver = {
    enable = true;
    # buffer = 250;
    # streamBuffer = 250;
    streams = {
      bluetooth = {
        type = "pipe";
        location = "/run/snapserver/bluetooth";
      };
      pulse = {
        type = "pipe";
        location = "/run/snapserver/spotifyd";
      };
      debug = {
        type = "pipe";
        location = "/run/snapserver/debug";
      };
      mopidy = {
        type = "pipe";
        location = "/run/snapserver/mopidy";
      };
    };
  };

  # create a pipe for pulseaudio after the daemon has started & ensure that pulseaudio starts *after* snapserver
  systemd.services.pulseaudio = {
    after = [ "snapserver.service" ];
    wants = [ "snapserver.service" ];
  };

  hardware.pulseaudio.extraConfig = ''
    load-module module-pipe-sink file=/run/snapserver/spotifyd sink_name="Spotifyd sink" format=s16le rate=48000
    load-module module-pipe-sink file=/run/snapserver/debug sink_name="Debug sink" format=s16le rate=48000
  '';

  imports = [
    (mkSnapClient "HDMI" "alsa_output.platform-hdmi-sound.multichannel-output")
    (mkSnapClient "BT Speaker" "bluez_sink.F4_4E_FD_7F_AE_F0.a2dp_sink")
  ];

  services.home-assistant.config.media_player = [
    {
      platform = "snapcast";
      host = "127.0.0.1";
    }
  ];
}

{ pkgs, ... }:
{
  services.snapserver = {
    enable = true;
    streams = {
      bluetooth = {
        type = "pipe";
        location = "/run/snapserver/bluetooth";
      };
      pulse = {
        type = "pipe";
        location = "/run/snapserver/pulse";
      };
    };
  };

  # create a pipe for pulseaudio after the daemon has started & ensure that pulseaudio starts *after* snapserver
  systemd.services.pulseaudio = {
    after = [ "snapserver.service" ];
    wants = [ "snapserver.service" ];
  };
  hardware.pulseaudio.extraConfig = ''
    load-module module-pipe-sink file=/run/snapserver/pulse sink_name=Snapcast format=s16le rate=48000
  '';

  systemd.services.snapclient-local = {
    after = [ "snapserver.service" "pulseaudio.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.snapcast ];
    script = ''
      exec snapclient --hostID crappy --host 127.0.0.1 --player pulse
    '';
    environment.HOME = "%t/snapclient-local";
    serviceConfig = {
      DynamicUser = true;
      RuntimeDirectory = "snapclient-local";
      WorkingDirectory = "%t/snapclient-local";
      User = "local-snapclient";
      Group = "local-snapclient";
      PrivateTmp = true;
      ProtectHome = true;
      PrivateMounts = true;
      PrivateDevices = true;
    };
  };

  services.home-assistant.config.media_player = [
    {
      platform = "snapcast";
      host = "127.0.0.1";
    }
  ];
}

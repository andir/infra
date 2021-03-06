{ config, pkgs, lib, ... }: {

  services.nginx = {
    enable = true;
    package = pkgs.nginxStable.override {
      modules = with pkgs.nginxModules; [
        rtmp
        dav
        moreheaders
      ];
    };
    virtualHosts."jetzt.kack.it" = {
      enableACME = true;
      forceSSL = true;
      locations."/hls".extraConfig = ''
        # Serve HLS fragments
        types {
          application/vnd.apple.mpegurl m3u8;
          video/mp2t ts;
        }
        root /var/lib/rtmp/tmp;

        # Allow CORS preflight requests
        if ($request_method = 'OPTIONS') {
          add_header 'Access-Control-Allow-Origin' '*';
          add_header 'Access-Control-Max-Age' 1728000;
          add_header 'Content-Type' 'text/plain charset=UTF-8';
          add_header 'Content-Length' 0;
          return 204;
        }

        if ($request_method != 'OPTIONS') {
          add_header Cache-Control no-cache;

          # CORS setup
          add_header 'Access-Control-Allow-Origin' '*' always;
          add_header 'Access-Control-Expose-Headers' 'Content-Length';
        }
      '';
      locations."/dash".extraConfig = ''
        # Serve DASH fragments
        types {
          application/dash+xml mpd;
          video/mp4 mp4;
        }
        root /var/lib/rtmp/tmp;

        # Allow CORS preflight requests
        if ($request_method = 'OPTIONS') {
          add_header 'Access-Control-Allow-Origin' '*';
          add_header 'Access-Control-Max-Age' 1728000;
          add_header 'Content-Type' 'text/plain charset=UTF-8';
          add_header 'Content-Length' 0;
          return 204;
        }
        if ($request_method != 'OPTIONS') {
          add_header Cache-Control no-cache;

          # CORS setup
          add_header 'Access-Control-Allow-Origin' '*' always;
          add_header 'Access-Control-Expose-Headers' 'Content-Length';
        }
      '';
      locations."= /dash.all.min.js".extraConfig = ''
        default_type "text/javascript";
        alias ${pkgs.fetchurl {
          url = "http://cdn.dashjs.org/v3.2.0/dash.all.min.js";
          sha256 = "16f0b40gdqsnwqi01s5sz9f1q86dwzscgc3m701jd1sczygi481c";
        }};
      '';
      locations."= /".return = "302 /player";
      locations."= /player".extraConfig = ''
        default_type "text/html";
        alias ${pkgs.writeText "player.html" ''
          <!DOCTYPE html>
          <html lang="en">
            <head>
              <meta charset="utf-8">
              <title>lassulus livestream</title>
            </head>
            <body>
              <div>
                <video id="player" controls></video>
                </video>
              </div>
              <script src="/dash.all.min.js"></script>
              <script>
                (function(){
                  var url = "/dash/nixos.mpd";
                  var player = dashjs.MediaPlayer().create();
                  player.initialize(document.querySelector("#player"), url, true);
                })();
              </script>
            </body>
          </html>
        ''};
      '';
      locations."/records".extraConfig = ''
        autoindex on;
        root /var/lib/rtmp;
      '';
    };
    appendConfig = ''
      rtmp {
        server {
          listen 1935;
          ping 30s;
          notify_method get;

          application stream {
            live on;

            hls on;
            hls_path /var/lib/rtmp/tmp/hls;
            hls_fragment 2;

            dash on;
            dash_fragment 1;
            dash_playlist_length 6s;
            dash_path /var/lib/rtmp/tmp/dash;
          }
        }
      }
    '';
  };
  systemd.services.nginx.serviceConfig.ReadWritePaths = [ "/var/lib/rtmp" ];

  systemd.tmpfiles.rules = [
    "d /var/lib/rtmp 0700 nginx - - -"
    "d /var/lib/rtmp/tmp 0700 nginx - - -"
    "d /var/lib/rtmp/tmp/hls 0700 nginx - - -"
    "d /var/lib/rtmp/tmp/dash 0700 nginx - - -"
  ];
}

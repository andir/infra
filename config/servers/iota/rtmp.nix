{ config, pkgs, lib, ... }:
let
  dashjs_src = pkgs.fetchzip {
    url = "https://github.com/Dash-Industry-Forum/dash.js/archive/refs/tags/v4.0.1.zip";
    sha256 = "1q1jbrh41h9yviprla88872dfm2w0wmp8iv2gn343biw92wn6zlg";
  };

  dashjs = pkgs.runCommand "dash.js" { inherit dashjs_src; } ''
    cp $dashjs_src/dist/dash.all.min.js $out
  '';
  fragmentLengthSeconds = 4;
in
{

  services.nginx = {
    enable = true;
    package = pkgs.nginxStable.override {
      modules = with pkgs.nginxModules; [
        rtmp
        dav
        moreheaders
        lua
      ];
    };
    virtualHosts."jetzt.kack.it" = {
      enableACME = true;
      forceSSL = true;
      locations."/time".extraConfig = ''
        client_max_body_size 10k;
        client_body_buffer_size 10k;
        default_type "text/plain";
        content_by_lua_block {
          ngx.req.read_body()
          local date = os.date("!%Y-%m-%dT%H:%M:%SZ")
          ngx.say(date)
        }
      '';
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
        alias ${dashjs};
      '';
      locations."= /".return = "302 /player";
      locations."= /player".extraConfig = ''
        default_type "text/html";
        alias ${pkgs.writeText "player.html" ''
          <!DOCTYPE html>
          <html lang="en">
            <head>
              <meta charset="utf-8">
              <title>livestream</title>
              <style>
                video {
                  max-width: 1920px;
                  max-height: 1080px;
                  height: 100vh;
                  width: 100vw;
                }
                body {
                  margin: 0;
                  padding: 0;
                  background-color: black;
                  width: 100%;
                  height: 100%;
                  display: flex;
                  align-teims: center;
                  justify-content: center;
                }
              </style>
            </head>
            <body>
              <script src="/dash.all.min.js"></script>
              <video id="player" controls="true"></video>
              <div id="debug" style="display: none">
                <p>WClock: <span id="min"></span>:<span id="sec"></span></p>
                <p>Delay: <span id="delay"></span></p>
                <p>Buffer: <span id="buffer"></span></p></p>
              </div>

              <script>
                var video = document.querySelector('#player');
                var player = dashjs.MediaPlayer().create();
                player.clearDefaultUTCTimingSources();
                player.updateSettings(${builtins.toJSON {
                  streaming = {
                    #delay.liveDelayFragmentCount = 2;
                    #delay.liveDelay = 2;
                    gaps = {
                      jumpGaps = false;
                      jumpLargeGaps = true;
                      smallGapLimit = 1.5;
                    };
                    utcSynchronization = {
                      defaultTimingSource = {
                        scheme = "urn:mpeg:dash:utc:http-xsdate:2014";
                        value = "/time";
                    };
                  };
                };
                }});
                player.initialize(video, "/dash/andi.mpd", true);

                setInterval(function() {
                  var d = new Date();
                  var seconds = d.getSeconds();
                  var minutes = d.getMinutes();
                  document.querySelector("#sec").innerHTML = (seconds < 10 ? '0' : '${""}') + seconds;
                  document.querySelector("#min").innerHTML = (minutes < 10 ? '0' : '${""}') + minutes;

                  var delay = Math.round((d.getTime() / 1000) - Number(player.timeAsUTC()));
                  document.querySelector("#delay").innerHTML = delay;

                  var buffer = player.getBufferLength();
                  document.querySelector("#buffer").innerHTML = buffer;
                }, 1000);
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
          listen [::]:1935;
          ping 30s;
          notify_method get;

          application stream {
            live on;

            hls on;
            hls_path /var/lib/rtmp/tmp/hls;
            hls_fragment ${toString fragmentLengthSeconds}s;
            hls_playlist_length ${toString (fragmentLengthSeconds * 4)}s;

            dash on;
            dash_fragment ${toString fragmentLengthSeconds}s;
            dash_playlist_length ${toString (fragmentLengthSeconds * 4)}s;
            dash_path /var/lib/rtmp/tmp/dash;

            allow publish 172.20.24.0/24;
            allow play 172.20.24.0/24;
            deny publish all;
            deny play all;
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

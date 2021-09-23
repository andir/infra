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
        gzip_types application/dash+xml;
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
      locations."= /player.config.js".alias = pkgs.writeText "player.config.js" (
        "window.playerConfig = " +
        (builtins.toJSON {
          dashjsConfig.streaming = {
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
          urls = {
            dash = "/dash/andi.mpd";
            hls = "/hls/andi.m3u8";
          };
        }) + ";"
      );

      locations."= /player" = {
        alias = ./rtmp.html;
        extraConfig = ''
          default_type "text/html";
        '';
      };
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

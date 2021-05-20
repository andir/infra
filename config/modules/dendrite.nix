{ pkgs, lib, config, ... }:
let
  cfg = config.h4ck.dendrite;

  dendriteConfig = {
    version = 1;
    global = {
      server_name = cfg.serverName;
      private_key = "matrix_key.pem";
      key_validity_period = "168h0m0s";
      trusted_third_party_id_servers = [ "matrix.org" "vector.im" ];
      disable_federation = cfg.disableFederation;
      kafka = {
        use_naffka = true;
        topic_prefix = "Dendrite";
        naffka_database = {
          connection_string = "file:naffka.db";
          max_open_conns = 10;
          max_idle_conns = 2;
          conn_max_lifetime = -1;
        };
      };
      metrics = {
        enabled = true;
      };
    };
    app_service_api = {
      internal_api = {
        listen = "http://localhost:7777";
        connect = "http://localhost:7777";
      };
      database = {
        connection_string = "file:appservice.db";
        max_open_connections = 10;
        max_idle_conns = 2;
        conn_max_lifetime = -1;
      };
      config_files = [ ];
    };

    client_api = {
      internal_api = {
        listen = "http://localhost:7771";
        connect = "http://localhost:7771";
      };
      external_api = {
        listen = "http://localhost:8071";
      };

      registration_disabled = cfg.registrationDisabled;
      enable_registration_captcha = false;
      turn = { };
      rate_limiting = {
        enabled = true;
        threshold = 5;
        cooloff_ms = 500;
      };
    };

    edu_server = {
      internal_api = {
        listen = "http://localhost:7778";
        connect = "http://localhost:7778";
      };
    };

    federation_api = {
      internal_api = {
        listen = "http://localhost:7772";
        connect = "http://localhost:7772";
      };
      external_api = {
        listen = "http://localhost:8072";
      };
      federation_certificates = [ ];
    };

    federation_sender = {
      internal_api = {
        listen = "http://localhost:7775";
        connect = "http://localhost:7775";
      };
      database = {
        connection_string = "file:federationsender.db";
        max_open_conns = 10;
        max_idle_conns = 2;
        conn_max_lifetime = -1;
      };

      send_max_retries = 16;
      disable_tls_verification = false;

      proxy_outbound.enabled = false;
    };

    key_server = {
      internal_api = {
        listen = "http://localhost:7779";
        connect = "http://localhost:7779";
      };
      database = {
        connection_string = "file:keyserver.db";
        max_open_conns = 10;
        max_idle_conns = 2;
        conn_max_lifetime = -1;
      };
    };
    media_api = {
      internal_api = {
        listen = "http://localhost:7774";
        connect = "http://localhost:7774";
      };
      external_api.listen = "http://localhost:8074";
      database = {
        connection_string = "file:mediaapi.db";
        max_open_conns = 10;
        max_idle_conns = 2;
        conn_max_lifetime = -1;
      };

      base_path = "./media_store";
      max_file_size_bytes = 1024 * 1024 * 25;
      dynamic_thumbnails = true;
      max_thumbnail_generators = 2;
      thumbnail_sizes = [
        { width = 32; height = 32; method = "crop"; }
        { width = 96; height = 96; method = "crop"; }
        { width = 640; height = 480; method = "scale"; }
      ];
    };

    mscs = {
      mscs = [ ];
      database = {
        connection_string = "file:mscs.db";
        max_open_conns = 10;
        max_idle_conns = 2;
        conn_max_lifetime = -1;
      };
    };

    room_server = {
      internal_api = {
        listen = "http://localhost:7770";
        connect = "http://localhost:7770";
      };
      database = {
        connection_string = "file:roomserver.db";
        max_open_conns = 10;
        max_idle_conns = 2;
        conn_max_lifetime = -1;
      };
    };

    signing_key_server = {
      internal_api = {
        listen = "http://localhost:7780";
        connect = "http://localhost:7780";
      };
      database = {
        connection_string = "file:signingserver.db";
        max_open_conns = 10;
        max_idle_conns = 2;
        conn_max_lifetime = -1;
      };
      prefer_direct_fetch = true;
      key_perspectives = [
        {
          server_name = "matrix.org";
          keys = [
            { key_id = "ed25519:auto"; public_key = "Noi6WqcDj0QmPxCNQqgezwTlBKrfqehY1u2FyWP9uYw"; }
            { key_id = "ed25519:a_RXGa"; public_key = "l8Hft5qXKn1vfHrg3p4+W8gELQVo8N13JkluMfmn2sQ"; }
          ];
        }
      ];
    };

    sync_api = {
      internal_api = {
        listen = "http://localhost:7773";
        connect = "http://localhost:7773";
      };
      external_api.listen = "http://localhost:8073";
      database = {
        connection_string = "file:syncapi.db";
        max_open_conns = 10;
        max_idle_conns = 2;
        conn_max_lifetime = -1;
      };
    };

    user_api = {
      internal_api = {
        listen = "http://localhost:7781";
        connect = "http://localhost:7781";
      };
      account_database = {
        connection_string = "file:userapi_accounts.db";
        max_open_conns = 10;
        max_idle_conns = 2;
        conn_max_lifetime = -1;
      };

      device_database = {
        connection_string = "file:userapi_devices.db";
        max_open_conns = 10;
        max_idle_conns = 2;
        conn_max_lifetime = -1;
      };
    };

    tracing.enabled = false;
    logging = [ ];
  };

in
{
  options.h4ck.dendrite = {
    enable = lib.mkEnableOption "enable dendrite";
    nginxVhost = lib.mkOption {
      type = lib.types.str;
    };
    registrationDisabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    disableFederation = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    serverName = lib.mkOption {
      type = lib.types.str;
    };

    monitoringHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "::1" "127.0.0.1" ];
    };
  };
  config = lib.mkIf cfg.enable {
    services.nginx.virtualHosts.${cfg.nginxVhost} = {
      locations = {
        "/.well-known/matrix/server".extraConfig = ''
          return 200 '{ "m.server": "${cfg.nginxVhost}:443" }';
        '';
        "/.well-known/matrix/client".extraConfig = ''
          return 200 '{ "m.homeserver": { "base_url": "https://${cfg.nginxVhost}" } }';
        '';
        "/_matrix".proxyPass = "http://localhost:8008";

        "/metrics" = {
          proxyPass = "http://localhost:8008";
          extraConfig = ''
            proxy_set_header Authorization "Basic bWV0cmljczptZXRyaWNz";
            access_log off;
            ${lib.concatMapStringsSep "\n" (host: "allow ${host};") cfg.monitoringHosts}
            deny all;
          '';
        };
      };
    };
    services.nginx.virtualHosts.${cfg.serverName} = {
      locations = {
        "/.well-known/matrix/server".extraConfig = ''
          return 200 '{ "m.server": "${cfg.nginxVhost}:443" }';
        '';
        "/.well-known/matrix/client".extraConfig = ''
          return 200 '{ "m.homeserver": { "base_url": "https://${cfg.nginxVhost}" } }';
        '';
      };
    };

    systemd.services.dendrite = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      path = [
        pkgs.dendrite
      ];
      # on Go >1.14 && <1.16 the way memory is released was changed
      # This has been reverted in Go 1.16 see:
      # - https://github.com/matrix-org/dendrite/issues/1580
      # - https://github.com/golang/go/issues/42330
      #environment.GODEBUG = "madvdontneed=1";
      script = ''
        cd $STATE_DIRECTORY
        test -e matrix_key.pem || generate-keys --private-key matrix_key.pem
        exec dendrite-monolith-server -config ${pkgs.writeText "config.yaml" (builtins.toJSON dendriteConfig)}
      '';
      serviceConfig = {
        User = "dendrite";
        DynamicUser = true;
        StateDirectory = "dendrite";
        RuntimeDirectory = "dendrite";
        Restart = "always"; # now that I use this for active communication with the Nix community keep it alive!
      };
    };
  };
}

{ pkgs, lib, config, ... }:
{
  h4ck.monitoring.targets.synapse = {
    port = 443;
    targetHost = "guest.nixos.dev";
    job_config = {
      scheme = "https";
    };
  };


  networking.firewall.allowedTCPPorts = [ 80 443 ];
  services.nginx = {
    enable = true;
    virtualHosts."guest.nixos.dev" = {
      enableACME = true;
      forceSSL = true;
      locations = {
        "/.well-known/matrix/server".extraConfig =
          let
            server."m.server" = "guest.nixos.dev:443";
          in
          ''
            add_header Content-Type application/json;
            return 200 '${builtins.toJSON server}';
          '';
        "/.well-known/matrix/client".extraConfig =
          let
            client."m.homeserver".base_url = "https://guest.nixos.dev";
          in
          ''
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
            return 200 '${builtins.toJSON client}';
          '';
        "/_matrix/" = {
          proxyPass = "http://[::1]:8448";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;'';
        };
        "/_synapse/" = {
          proxyPass = "http://[::1]:8448";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;'';
        };
        "/metrics" = {
          proxyPass = "http://127.0.0.1:9148";
          extraConfig = ''
            access_log off;
            ${lib.concatMapStringsSep "\n" (host: "allow ${host};") (config.h4ck.monitoring.defaultMonitoringHosts ++ [ "127.0.0.1" "::1" ])}
            deny all;
          '';

        };

        "/" = {
          root = pkgs.element-web.override (_: {
            conf = {
              default_server_config."m.homeserver" = {
                server_name = "guest.nixos.dev";
                base_url = "https://guest.nixos.dev";
              };
              integrations_ui_url = "";
              integgrations_rest_url = "";
              integrations_widgets_urls = [ ];
              disable_guests = false;
              roomDirectory.servers = [ "nixos.org" "guest.nixos.dev" "kack.it" ];
              features = {
                feature_pinning = "labs";
                feature_custom_status = "labs";
                feature_custom_tags = "labs";
                feature_state_counters = "labs";
              };
              disable_custom_urls = true;
              showLabsSettings = true;
            };
          });
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /persist/synapse 0700 matrix-synapse - - -"
  ];
  services.matrix-synapse = {
    enable = true;
    server_name = "guest.nixos.dev";
    public_baseurl = "https://guest.nixos.dev";
    dataDir = "/persist/synapse";
    database_type = "psycopg2";
    database_args = {
      user = "matrix-synapse";
      database = "matrix-synapse";
      cp_min = 5;
      cp_max = 10;
    };
    report_stats = true;
    enable_metrics = true;
    listeners = [
      {
        type = "metrics";
        port = 9148;
        bind_address = "127.0.0.1";
        resources = [ ];
        tls = false;
      }
      {
        bind_address = "::1";
        port = 8448;
        resources = [
          {
            compress = false;
            names = [
              "client"
            ];
          }
          {
            compress = false;
            names = [
              "federation"
            ];
          }
        ];
        tls = false;
        type = "http";
        x_forwarded = true;
      }
    ];

    servers = {
      "matrix.org" = {
        "ed25519:auto" = "Noi6WqcDj0QmPxCNQqgezwTlBKrfqehY1u2FyWP9uYw";
      };
      # "kack.it" = {
      # };
    };

    redaction_retention_period = 1;
    rc_messages_per_second = "0.2";
    rc_message_burst_count = "3";
    key_refresh_interval = "1h"; # for initial setup so we can invalidate the key earlier
    max_upload_size = "10M";
    url_preview_enabled = false;
    dynamic_thumbnails = false; # might be a nicer user experience?
    allow_guest_access = true;
    enable_registration = false; # for admin purposes
    logConfig = ''
      version: 1

      formatters:
        journal_fmt:
          format: '%(name)s: [%(request)s] %(message)s'

      filters:
        context:
          (): synapse.util.logcontext.LoggingContextFilter
          request: ""

      handlers:
        journal:
          class: systemd.journal.JournalHandler
          formatter: journal_fmt
          filters: [context]
          SYSLOG_IDENTIFIER: synapse

      disable_existing_loggers: True

      loggers:
        synapse:
          level: WARN
        synapse.handlers.oidc:
          level: DEBUG
        synapse.storage.SQL:
          level: WARN

      root:
        level: WARN
        handlers: [journal]
    '';


    extraConfigFiles = [
      (pkgs.writeText "misc.yml" (builtins.toJSON ({
        #session_lifetime = "24h"; # disabled to allow guest accounts
        experimental_features = { spaces_enabled = true; };
      })))
      (pkgs.writeText "retention.yml" (builtins.toJSON ({
        retention = {
          enabled = true;
          default_policy = {
            min_lifetime = "1d";
            max_lifetime = "90d";
          };

          allowed_lifetime_min = "1d";
          allowed_lifetime_max = "90d";

          purge_jobs = [
            {
              shorted_max_lifetime = "1d";
              longest_max_lifetime = "7d";
              interval = "5m";
            }
            {
              shorted_max_lifetime = "7d";
              longest_max_lifetime = "90d";
              interval = "24h";
            }
          ];
        };
      })))
      (pkgs.writeText "url-preview.yml" (builtins.toJSON ({
        url_preview_enabled = true;
        url_preview_ip_range_blacklist = [
          "127.0.0.0/8"
          "10.0.0.0/8"
          "172.16.0.0/12"
          "192.168.0.0/16"
          "100.64.0.0/10"
          "169.254.0.0/16"
          "::1/128"
          "fe80::/64"
          "fc00::/7"
        ];
        url_preview_url_blacklist = [
          {
            username = "*";
          }
          { netloc = "google.com"; }
          { netloc = "*.google.com"; }
          {
            netloc = "^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$";
          }
        ];
        max_spider_size = "10M";
      })))
      (pkgs.writeText "push.yml" (builtins.toJSON ({
        push.include_content = false;
      })))
    ];
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_12;
    initialScript = pkgs.writeText "synapse-init.sql" ''
      CREATE USER "matrix-synapse";
      CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
        TEMPLATE template0
        LC_COLLATE = "C"
        LC_CTYPE = "C";
    '';
    settings =
      # From http://pgconfigurator.cybertec.at/; https://git.darmstadt.ccc.de/maralorn/nixos-config/-/blob/master/nixos/roles/matrix-synapse/postgres-tuning.nix
      {
        # Connectivity;
        max_connections = 100;
        superuser_reserved_connections = 3;
        # Memory Settings;
        shared_buffers = "1024 MB";
        work_mem = "32 MB";
        maintenance_work_mem = "320 MB";
        huge_pages = "off";
        effective_cache_size = "3 GB";
        effective_io_concurrency = 100; # concurrent IO only really activated if OS supports posix_fadvise function;
        random_page_cost = 1.25; # speed of random disk access relative to sequential access (1.0);
        # Monitoring;
        shared_preload_libraries = "pg_stat_statements"; # per statement resource usage stats;
        track_io_timing = "on"; # measure exact block IO times;
        track_functions = "pl"; # track execution times of pl-language procedures if any;
        # Replication;
        wal_level = "replica"; # consider using at least "replica";
        max_wal_senders = 0;
        synchronous_commit = "on";

        # Checkpointing: ;
        checkpoint_timeout = "15 min";
        checkpoint_completion_target = 0.9;
        max_wal_size = "1024 MB";
        min_wal_size = "512 MB";


        # WAL writing;
        wal_compression = "on";
        wal_buffers = -1; # auto-tuned by Postgres till maximum of segment size (16MB by default);
        wal_writer_delay = "200ms";
        wal_writer_flush_after = "1MB";


        # Background writer;
        bgwriter_delay = "200ms";
        bgwriter_lru_maxpages = 100;
        bgwriter_lru_multiplier = 2.0;
        bgwriter_flush_after = 0;

        # Parallel queries: ;
        max_worker_processes = 6;
        max_parallel_workers_per_gather = 3;
        max_parallel_maintenance_workers = 3;
        max_parallel_workers = 6;
        parallel_leader_participation = "on";

        # Advanced features ;
        enable_partitionwise_join = "on";
        enable_partitionwise_aggregate = "on";
        jit = "on";
      };
  };

  # use jemalloc to improve the memory situation with synapse
  systemd.services.matrix-synapse.environment.LD_PRELOAD = "${pkgs.jemalloc}/lib/libjemalloc.so";
}
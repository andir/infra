{ pkgs, lib, config, ... }:
{
  h4ck.monitoring.targets.synapse = {
    port = 443;
    targetHost = "matrix.kack.it";
    job_config = {
      scheme = "https";
    };
  };

  h4ck.backup.paths = [ "/var/lib/matrix-synapse" "/var/lib/postgresql" ];

  services.nginx = {
    enable = true;
    virtualHosts."kack.it" = {
      enableACME = true;
      forceSSL = true;
      locations = {
        "/.well-known/matrix/server".extraConfig =
          let
            server."m.server" = "matrix.kack.it:443";
          in
          ''
            add_header Content-Type application/json;
            return 200 '${builtins.toJSON server}';
          '';
        "/.well-known/matrix/client".extraConfig =
          let
            client."m.homeserver".base_url = "https://matrix.kack.it";
          in
          ''
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
            return 200 '${builtins.toJSON client}';
          '';
        "/_matrix/".return = "307 http://matrix.kack.it$request_uri";
      };
    };
    virtualHosts."element.kack.it" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        root = pkgs.element-web.override (_: {
          conf = {
            default_server_config."m.homeserver" = {
              server_name = "kack.it";
              base_url = "https://matrix.kack.it";
            };
            integrations_ui_url = "";
            integgrations_rest_url = "";
            integrations_widgets_urls = [ ];
            disable_guests = true;
            roomDirectory.servers = [ "nixos.org" "kack.it" "matrix.org" ];
            features = {
              feature_pinning = "labs";
              feature_custom_status = "labs";
              feature_custom_tags = "labs";
              feature_state_counters = "labs";
            };
            showLabsSettings = true;
          };
        });
      };
    };
    virtualHosts."matrix.kack.it" = {
      enableACME = true;
      forceSSL = true;
      locations = {
        "~* ^(\\/_matrix|\\/_synapse\\/client)" = {
          proxyPass = "http://[::1]:8448";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 900s;
          '';
        };
        #        "/_synapse/" = {
        #          proxyPass = "http://[::1]:8448";
        #          extraConfig = ''
        #            proxy_set_header Host $host;
        #            proxy_set_header X-Forwarded-For $remote_addr;
        #            proxy_set_header X-Forwarded-Proto $scheme;'';
        #        };
        "/metrics" = {
          proxyPass = "http://127.0.0.1:9148";
          extraConfig = ''
            access_log off;
            ${lib.concatMapStringsSep "\n" (host: "allow ${host};") (config.h4ck.monitoring.defaultMonitoringHosts ++ [ "127.0.0.1" "::1" ])}
            deny all;
          '';
        };
      };
    };
  };

  services.matrix-synapse = {
    enable = true;

    settings = {

      server_name = "kack.it";
      public_baseurl = "https://matrix.kack.it";
      report_stats = true;
      enable_metrics = true;
      database.name = "psycopg2";
      database.args = {
        user = "matrix-synapse";
        database = "matrix-synapse";
        cp_min = 5;
        cp_max = 10;
      };


      trusted_key_servers = [
        {
          server_name = "matrix.org";
          verify_keys = {
            "ed25519:auto" = "Noi6WqcDj0QmPxCNQqgezwTlBKrfqehY1u2FyWP9uYw";
          };
          # "kack.it" = {
          # };
        }
      ];
      listeners = [
        {
          type = "metrics";
          port = 9148;
          bind_addresses = [ "127.0.0.1" ];
          resources = [ ];
          tls = false;
        }
        {
          bind_addresses = [ "::1" ];
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



      redaction_retention_period = 1;
      rc_messages_per_second = 10;
      rc_message_burst_count = 15;
      key_refresh_interval = "8h"; # for initial setup so we can invalidate the key earlier
      max_upload_size = "10M";
      url_preview_enabled = true;
      dynamic_thumbnails = false; # might be a nicer user experience?
      allow_guest_access = false;
      enable_registration = false; # for admin purposes
      enable_registration_without_verification = false;
      log_config = pkgs.writeText "config.yaml" ''
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
          synapse.storage.SQL:
            level: WARN

        root:
          level: WARN
          handlers: [journal]
      '';
    };
    extraConfigFiles = [
      (pkgs.writeText "misc.yml" (builtins.toJSON ({
        #session_lifetime = "24h"; # disabled to allow guest accounts
        # experimental_features = { spaces_enabled = true; };
      })))
      (pkgs.writeText "retention.yml" (builtins.toJSON ({
        retention = {
          enabled = true;
          default_policy = {
            min_lifetime = "1d";
            max_lifetime = "36500d";
          };

          #allowed_lifetime_min = "1d";
          #allowed_lifetime_max = "365d";

          #purge_jobs = [
          #  {
          #    shorted_max_lifetime = "1d";
          #    longest_max_lifetime = "7d";
          #    interval = "5m";
          #  }
          #  {
          #    shorted_max_lifetime = "7d";
          #    longest_max_lifetime = "90d";
          #    interval = "24h";
          #  }
          #];
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

  boot.initrd.luks.devices = {
    "postgresql".device = "/dev/disk/by-uuid/cf0d0b47-2f49-49b8-8feb-b3a6a4f41a2c";
  };
  fileSystems."/var/lib/postgresql" = {
    fsType = "ext4";
    device = "/dev/disk/by-uuid/f4da6312-9da8-4d65-8881-d741ecb15f51";
  };
  #fileSystems."/var/lib/postgresql" = {
  #  fsType = "none";
  #  options = [ "bind" ];
  #  device = "/data/postgresql/data";
  #};

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
        effective_cache_size = "2 GB";
        effective_io_concurrency = 100; # concurrent IO only really activated if OS supports posix_fadvise function;
        random_page_cost = 1.25; # speed of random disk access relative to sequential access (1.0);
        # Monitoring;
        shared_preload_libraries = "pg_stat_statements,auto_explain"; # per statement resource usage stats & log explain statements for slow queries
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

        jit_above_cost = 100000;
        jit_inline_above_cost = 150000;
        jit_optimize_above_cost = 500000;

        # log slow queries
        log_min_duration_statement = 100;
        "auto_explain.log_min_duration" = 100;
      };
  };

  # use mimalloc to improve the memory situation with synapse
  systemd.services.matrix-synapse.environment = {
    LD_PRELOAD = "${pkgs.mimalloc}/lib/libmimalloc.so";
    SYNAPSE_CACHE_FACTOR = "1.0";
    LimitNOFILE = "4096";
  };

  h4ck.compact-matrix-states.enable = true;
}

{ pkgs, lib, config, ... }:
let
  nginxCfg = config.services.nginx;
  acmeDirectory = "/var/lib/acme";

  prosodyHttpPort = 5280;
  prosodyHttpsPort = 5281;

  cfg = config.h4ck.prosody;

in
{

  options = {
    h4ck.prosody = {
      enable = lib.mkEnableOption "Enable prosody";
      serverName = lib.mkOption {
        type = lib.types.str;
      };
      adminJID = lib.mkOption {
        type = lib.types.str;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    h4ck.backup.paths = [ "/var/lib/prosody" ];
    services.prosody = let
      sslOptions = {
        ciphers = "HIGH+kEECDH:HIGH+kEDH:!DSS:!ECDSA:!3DES:!aNULL:@STRENGTH";
        options = [ "no_sslv2" "no_sslv3" "no_ticket" "no_compression" "cipher_server_preference" ];
      };
    in
      {
        enable = true;
        package = pkgs.prosody.override {
          withCommunityModules = [
            "carbons_adhoc"
            "cloud_notify"
            "csi"
            "http_upload"
            "mam_adhoc"
            "omemo_all_access"
            "reload_modules"
            "smacks"
            "throttle_presence"
            "filter_chatstates"
            "vcard_muc"
            "bookmarks"
            "conversejs"
          ];
        };
        allowRegistration = false;
        admins = [ cfg.adminJID ];
        ssl = {
          cert = "${acmeDirectory}/${cfg.serverName}/fullchain.pem";
          key = "${acmeDirectory}/${cfg.serverName}/key.pem";
          extraOptions = sslOptions;
        };

        # standard configuration
        modules = {
          admin_telnet = true;
          admin_adhoc = true;
          mam = true;
          carbons = true;
          pep = true;
          roster = true;
        };
        extraConfig = ''

        -- configure logging
        -- log = {
        --   { to = "console", levels = { min = "debug" } }
        -- }


        -- hash passwords in the internal database
        authentication = "internal_hashed"

        -- store data on disk non-fancy formats
        storage = "internal"

        -- support xmpps client support via SRV record
        -- _xmpps-client._tcp.example.com. 18000 IN SRV 0 5 5222 xmpp.example.com.
        legacy_ssl_ports = { 5223 }

        -- http
        http_ports = { ${toString prosodyHttpPort} }
        http_interfaces = { "*" }
        https_ports = { ${toString prosodyHttpsPort} }
        https_interfaces = { "*" }

        http_external_url = "https://${cfg.serverName}/.xmpp/"

        -- http upload
        http_upload_file_size_limit = 16777216
        http_max_content_size = 25165824

        -- module: bosh
        bosh_max_inactivity = 180
        consider_bosh_secure = true
        cross_domain_bosh = false

        -- module: mam
        default_archive_policy = "roster"
        archive_expires_after = "4w"
        max_archive_query_results = 50

        -- module: reload_modules
        -- reload certificates after reload
        reload_modules = { "tls" }

        -- module: cloud_notify
        push_notification_with_body = false
        push_notification_with_sender = false
        push_max_errors = 16
        push_notification_important_body = ""
        push_max_devices = 10

        -- trust websocket from any source, nginx enforces origins
        cross_domain_websocket = true

        Component "proxy.${cfg.serverName}" "proxy65"
                proxy65_address = "${cfg.serverName}"
                proxy65_acl = { "${cfg.serverName}" }

        Component "upload.${cfg.serverName}" "http_upload"

        Component "conference.${cfg.serverName}" "muc"
                name = "kack.it's MUCs"
                restrict_room_creation = "local"
                max_history_messages = 20000
                muc_room_default_public = false
                muc_log_by_default = true
                muc_log_presences = false
                log_all_rooms = false
                muc_log_expires_after = "1w"
                muc_log_cleanup_interval = 4 * 60 * 60
                modules_enabled = { "muc_mam", "vcard_muc", }
      '';
        extraModules = [
          "reload_modules"
          "http"
          "http_upload"
          "smacks" # XEP-0198: messages are queued until they get acked. useful for instable c2s connections
          "carbons_adhoc" # http://modules.prosody.im/mod_carbons_adhoc.html
          "csi" # client state indication
          "filter_chatstates"
          "throttle_presence"
          "mam_adhoc"
          "blocklist"
          "cloud_notify"
          "proxy65"
          "omemo_all_access" # disable restrictions on accessing the OMEMO keys
          "vcard_legacy" # XEP-0398: User Avatar to vCard-Based Avatars Conversion
          "bosh" # enable accessing server via HTTP(s)
          "websocket" # enable accessing the server via WS over HTTPS
          "bookmark"
          "conversejs"
        ];

        # all the different domains this server serves go here
        virtualHosts = {
          kackit = {
            enabled = true;
            domain = "${cfg.serverName}";
            ssl = {
              cert = "${acmeDirectory}/${cfg.serverName}/fullchain.pem";
              key = "${acmeDirectory}/${cfg.serverName}/key.pem";
              extraOptions = sslOptions;
            };
          };
        };
      };

    networking.firewall.allowedTCPPorts = [
      5000
      5222
      5223 # legacy SSL
      5269
      80
      443

      # the prosody HTTP ports are proxied through the local NGINX
      # prosodyHttpPort
      # prosodyHttpsPort
    ];

    # enable nginx with ACME for our certificates
    services.nginx = let
      host-meta-json = pkgs.writeText "host-meta.json" (
        builtins.toJSON {
          links = [
            {
              rel = "urn:xmpp:alt-connections:xbosh";
              href = "https://${cfg.serverName}/.xmpp/http-bind";
            }
            {
              rel = "urn:xmpp:alt-connections:websocket";
              href = "wss://${cfg.serverName}/.xmpp/ws";
            }

          ];
        }
      );
      host-meta = pkgs.writeText "host-meta.xml" ''
        <?xml version='1.0' encoding='utf-8'?>
        <XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>
          <Link rel="urn:xmpp:alt-connections:xbosh" href="https://${cfg.serverName}/.xmpp/http-bind" />
          <Link rel="urn:xmpp:alt-connections:websocket" href="wss://${cfg.serverName}/.xmpp/ws" />
        </XRD>
      '';

      signal = pkgs.fetchurl {
        url = "https://cdn.conversejs.org/3rdparty/libsignal-protocol.min.js";
        sha256 = "08wbd4nqcjcfrpp5i4g4qnc0975v59l35vjirc58rcwyc2cr9qpy";
      };

      js = pkgs.fetchurl {
        url = "https://cdn.conversejs.org/6.0.0/dist/converse.min.js";
        sha256 = "05d8dyhqh3pq69ifjhr65c937d3ll08iaxdxqjrjv08yki9micxk";
      };

      css = pkgs.fetchurl {
        url = "https://cdn.conversejs.org/6.0.0/dist/converse.min.css";
        sha256 = "1w4g6y9ji9jx84ic5fl452dyv116h5x96vj572y4f62xw7dlrfi7";
      };

      index = pkgs.writeText "index.html" ''
        <!doctype html>
        <html lang="en">
        <head>
          <meta chartset="utf-8"/>
          <link rel="stylesheet" type="text/css" media="screen" href="converse.css">
          <script src="signal.js" charset="utf-8"></script>
          <script src="converse.js" charset="utf-8"></script>
        </head>
        <body class="converse-fullscreen">
        <div id="conversejs-bg"></div>

        <script>
          converse.initialize({
              authentication: 'login',
              bosh_service_url: 'https://${cfg.serverName}/.xmpp/http-bind/',
              view_mode: 'fullscreen'
          });
        </script>
        </body>
        </html>
      '';
    in
      {
        enable = true;
        virtualHosts = {
          "${cfg.serverName}" = {
            forceSSL = true;
            enableACME = true;
            locations."/.xmpp/http-bind" = {
              extraConfig = ''
                add_header Access-Control-Allow-Origin '*' always;
                proxy_pass http://127.0.0.1:${toString prosodyHttpPort}/http-bind;
                proxy_set_header Host $host;
                proxy_set_header X-Forwarded-For $remote_addr;
                proxy_buffering off;
                tcp_nodelay on;
              '';
            };
            locations."/.xmpp/ws" = {
              extraConfig = ''
                add_header Access-Control-Allow-Origin '*' always;
                proxy_pass http://127.0.0.1:${toString prosodyHttpPort}/xmpp-websocket;
                proxy_http_version 1.1;
                proxy_set_header Connection "Upgrade";
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Host $host;
                proxy_set_header X-Forwarded-For $remote_addr;
                proxy_read_timeout 900s;
                proxy_buffering off;
              '';
            };
            locations."/.xmpp/" = {
              extraConfig = ''
                proxy_pass http://127.0.0.1:${toString prosodyHttpPort}/;
                proxy_set_header Host $host;
                proxy_set_header X-Forwarded-For $remote_addr;
              '';
            };
            locations."=/converse" = {
              extraConfig = ''
                default_type 'text/html';
                alias ${index};
              '';
            };
            locations."=/converse.js" = {
              extraConfig = ''
                default_type 'application/javascript';
                alias ${js};
              '';
            };
            locations."=/signal.js" = {
              extraConfig = ''
                default_type 'application/javascript';
                alias ${signal};
              '';
            };

            locations."=/converse.css" = {
              extraConfig = ''
                default_type 'text/css';
                alias ${css};
              '';
            };
            locations."=/.well-known/host-meta" = {
              extraConfig = ''
                default_type 'application/xrd+xml';
                add_header Access-Control-Allow-Origin '*' always;
                alias ${host-meta};
              '';
            };
            locations."=/.well-known/host-meta.json" = {
              extraConfig = ''
                default_type 'application/json+xml';
                add_header Access-Control-Allow-Origin '*' always;
                alias ${host-meta-json};
              '';
            };
          };
        };
      };

    security.acme.certs = {
      "${cfg.serverName}" = {
        group = "kackcerts";
        extraDomains."upload.${cfg.serverName}" = null;
        extraDomains."conference.${cfg.serverName}" = null;
        extraDomains."proxy.${cfg.serverName}" = null;
        # after creating new certificates reload prosody
        allowKeysForGroup = true;
        postRun = ''
          ${config.services.prosody.package}/bin/prosodyctl reload
        '';
      };
    };

    # put both nginx and prosody in a group that is used to read certificates and keys
    users.groups."kackcerts" = {
      members = [ "prosody" nginxCfg.user ];
    };

    # start prosody only after we ensured that there are at least self-signed certificates
    systemd.services.prosody = {
      after = [ "acme-selfsigned-certificates.target" "acme-certificates.target" ];
      wants = [ "acme-selfsigned-certificates.target" "acme-certificates.target" ];
    };
  };
}

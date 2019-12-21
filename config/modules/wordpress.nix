{ config, lib, pkgs, ... }:
with lib;
let

  cfg = config.wordpress;

  wordpress = { name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        internal = true;
      };
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      aliases = mkOption {
        type = types.listOf types.str;
        default = [];
      };
      letsencrypt = mkOption {
        default = true;
        type = types.bool;
      };
      documentRoot = mkOption {
        default = true;
        type = types.str;
      };
      phpfpmSock = mkOption {
        type = types.str;
      };
      mysqlUser = mkOption {
        type = types.str;
        internal = true;
      };
    };
    config = {
      name = mkDefault name;
      documentRoot = mkDefault "/var/lib/wordpress/${name}";
      phpfpmSock = mkDefault "/run/phpfpm/${name}.sock";
      mysqlUser = mkDefault (lib.replaceStrings ["."] ["_"] name);
    };
  };
in {
  options.wordpress = {
    instances = mkOption {
      type = types.loaOf (types.submodule wordpress);
      default = {};
    };
  };
  config = mkIf (cfg.instances != {}) {

    environment.systemPackages = mapAttrsToList (n: v:
      pkgs.writeScriptBin "${n}-wp-cli" ''
        #! ${pkgs.stdenv.shell}
        echo "Starting wp-cli in ${v.documentRoot} as user ${n}"
        cd ${v.documentRoot}
        exec su -s ${pkgs.writeScript "wp-cli" "exec ${pkgs.wp-cli}/bin/wp \"$@\""}  '${n}' -- "$@"
      ''
      ) cfg.instances;

    systemd.tmpfiles.rules = [
      "d '/var/lib/wordpress/' 0755 root root - -"
    ] ++ mapAttrsToList (n: v:
      "d '${v.documentRoot}' 0750 ${n} nginx - -"
    ) cfg.instances;

    users.users = mapAttrs (n: v: {
        isSystemUser = true;
        home = v.documentRoot;
        createHome = true;
      }) cfg.instances;

    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = mapAttrsToList (n: _: n) cfg.instances;
      ensureUsers = mapAttrsToList (n: v: { name = n; ensurePermissions = { "${v.mysqlUser}.*" = "ALL PRIVILEGES"; }; }) cfg.instances;
    };

    services.phpfpm = {
      phpOptions = ''
        opcache.enable = true;
      '';
      pools = mapAttrs (_: i: {
        phpPackage = pkgs.php73;
        user = i.name;
        group = "users";
        phpOptions = ''
          extension = "${pkgs.php73Packages.apcu}/lib/php/extensions/apcu.so";
          extension = "${pkgs.php73Packages.imagick}/lib/php/extensions/imagick.so";
        '';
        settings = {
          "listen.owner" = "nginx";
          "listen.group" = "nginx";
          pm = "dynamic";
          "pm.max_children" = 8;
          "pm.start_servers" = 1;
          "pm.min_spare_servers" = 1;
          "pm.max_spare_servers" = 4;
          "pm.max_requests" = 1024;
        };
      }) cfg.instances;
    };

    services.nginx = {
      enable = true;
      virtualHosts = mapAttrs (_: i: ({
        root = i.documentRoot;
        enableACME = i.letsencrypt;
        forceSSL = i.letsencrypt;
        serverAliases = i.aliases;
        locations = {
          "~ ^/blog/([^\\s])" = {
            extraConfig = ''
              return 301 /$1;
            '';
            priority = 100;
          };
          "= /robots.txt" = {
            extraConfig = ''
              allow all;
              log_not_found off;
              access_log off;
            '';
            priority = 100;
          };
          "~ ^/(README|INSTALL|LICENSE|CHANGELOG|UPGRADING)$" = {
            extraConfig = "deny all;";
            priority = 200;
          };
          "~ ^/(bin|SQL)" = {
            extraConfig = "deny all;";
            priority = 200;
          };
          "~ /\\." = {
            extraConfig = ''
              deny all;
              access_log off;
              log_not_found off;
            '';
            priority = 300;
          };
          "/" = {
            extraConfig = ''
              try_files $uri $uri/ /index.php?$args;
              index index.php;
            '';
            priority = 400;
          };

          "~ \\.php$" = {
            extraConfig = ''
              try_files $uri =404;
              fastcgi_pass unix:${i.phpfpmSock};
              fastcgi_index index.php;
              fastcgi_read_timeout 5s;
            '';
            priority = 500;
          };
        };
      })) cfg.instances;
    };
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };

}

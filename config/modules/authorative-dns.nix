{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.h4ck.authorative-dns;

  asBool = x: if x then "true" else "false";

  # indent = n:
  #  let
  #    prefix = lib.concatStrings (map (_: " ") (lib.genList 0 n));
  #  in str: lib.concatMapStringsSep "\n" (line: "${prefix}${line}") (if builtins.typeOf str == "list" then lib.flatten str else  (lib.splitString "\n" str));

  #i2 = indent 2;
  #i4 = indent 4;

  authZoneOptions = { name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
      };
      zoneFile = mkOption {
        type = types.path;
      };
      slaves = mkOption {
        type = types.attrsOf (types.submodule slaveOptions);
        default = {};
      };
    };
    config = {
      inherit name;
    };
  };

  slaveOptions = { name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
      };
      address = mkOption {
        type = types.str;
      };
      port = mkOption {
        type = types.port;
        default = 53;
      };
      keyName = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
    config = {
      inherit name;
    };
  };

  slaveZoneOptions = { name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
      };
      masters = mkOption {
        type = types.listOf types.str;
      };
      tsigKeyFile = mkOption {
        types = types.listOf types.str;
        default = [];
      };
      dnssecSigning = mkOption {
        type = types.bool;
        default = true;
      };

      semanticChecks = mkOption {
        type = types.bool;
        default = true;
      };

      storage = mkOption {
        type = types.str;
        default = "/var/lib/knot";
      };
    };
    config = {
      inherit name;
    };
  };
in
{

  options.h4ck.authorative-dns = {
    enable = mkEnableOption "Enable authorative dns server";

    listenAddresses = mkOption {
      type = types.listOf types.str;
      default = [ "::@53" "0.0.0.0@53" ];
    };

    verbose = mkOption {
      default = false;
      type = types.bool;
    };

    secondary = mkOption {
      default = null;
    };

    authZones = mkOption {
      type = types.attrsOf (types.submodule authZoneOptions);
      default = {};
    };
    slaveZones = mkOption {
      type = types.attrsOf (types.submodule slaveZoneOptions);
      default = {};
    };

    enableStats = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (builtins.intersectAttrs cfg.authZones cfg.slaveZones) == {};
        message = "auth zones can't overlap with slave zones (yet)";
      }
    ];
    environment.systemPackages = [ pkgs.ldns ];
    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = [ 53 ];
    systemd.tmpfiles.rules = [
      "d /var/lib/knot/keys - knot knot"
    ];
    services.knot = {
      enable = true;
      extraArgs = mkIf cfg.verbose [ "-v" ];
      extraConfig = let

        mkCheckedZone = zoneName: file: pkgs.runCommand "${zoneName}.zone" {
          buildInputs = [ pkgs.knot-dns ];
        } ''
          ln -s ${file} $out
          kzonecheck -o ${zoneName} -v $out
        '';

        authZoneFilesDir = pkgs.runCommand "zonefiles" {} (''
          mkdir $out
        ''
        + lib.concatStringsSep "\n" (
          lib.mapAttrsToList (_: zone: ''
            ln -s $(readlink -f "${mkCheckedZone zone.name zone.zoneFile}") "$out/${zone.name}.zone"
          '') cfg.authZones)
          );

        authZoneFile = name: zone: pkgs.writeText "zone-${name}.conf" ''
          remote:
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList
          (_: slave: ''
            - id: ${name}-${slave.name}
              address: ${slave.address}@${toString slave.port}
          '') zone.slaves)
          }
          acl:
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList
          (_: slave: ''
            - id: ${slave.name}-${zone.name}
              action: transfer
              address: ${slave.address}
              ${lib.optionalString (slave.keyName != null) "key: ${slave.keyName}"}
          '') zone.slaves)
          }
          zone:
            - domain: ${name}
              file: ${zone.name}.zone
              ${lib.optionalString (zone.slaves != {}) ''
              notify: [${lib.concatStringsSep ", " (lib.mapAttrsToList
                  (_: slave: "${name}-${slave.name}") zone.slaves)
              }]
              ''}
        '';

        slaveZoneFile = name: zone: pkgs.writeText "zone-${name}.conf" ''
          remote:
          ${lib.concatMapStringsSep "\n" (master: ''
            - id: ${name}-${master}
              address: ${master}
          '') zone.masters}
          acl:
            - id: ${name}_notify
              address: [${lib.concatStringsSep ", " zone.masters}]
              action: notify
          zone:
            - domain: ${name}
              acl: ${name}_notify
              semantic-checks: ${asBool zone.semanticChecks}
              dnssec-signing: ${asBool zone.dnssecSigning}
              storage: ${zone.storage}
              zonefile-sync: 0
              zonefile-load: whole
              journal-content: changes
              master: [${lib.concatStringsSep ", " (map (x: "${name}-${x}") zone.masters)}]
        '';

        authZoneFiles = lib.mapAttrsToList authZoneFile cfg.authZones;
        slaveZoneFiles = lib.mapAttrsToList slaveZoneFile cfg.slaveZones;

      in ''
        server:
        ${lib.concatMapStringsSep "\n" (addr: "  listen: ${addr}") cfg.listenAddresses}

        ${lib.optionalString cfg.enableStats ''
        mod-stats:
          - id: stats
            request-protocol: true
            server-operation: true
            request-bytes: true
            response-bytes: true
            edns-presence: true
            flag-presence: true
            response-code: true
            request-edns-option: true
            response-edns-option: true
            reply-nodata: true
            query-type: true
            query-size: true
            reply-size: true
        ''}

        template:
          - id: default
            storage: ${authZoneFilesDir}
            zonefile-sync: -1
            zonefile-load: difference
            journal-content: changes
            journal-db: /var/lib/knot/journal
            kasp-db: /var/lib/knot/kasp
            timer-db: /var/lib/knot/timer
            ${lib.optionalString cfg.enableStats "module: mod-stats/stats"}

        policy:
          - id: rsa
            zsk-size: 2048
            ksk-size: 1024
            algorithm: "RSASHA256"
            nsec3: true

        keystore:
          - id: default
            backend: pem
            config: /var/lib/knot/keys
        ${lib.concatMapStringsSep "\n" (file: "include: ${file}") authZoneFiles}
        ${lib.concatMapStringsSep "\n" (file: "include: ${file}") slaveZoneFiles}
      '';
    };
  };
}

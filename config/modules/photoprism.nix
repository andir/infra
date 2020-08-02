{ config, lib, pkgs, ... }:
let
  cfg = config.h4ck.photoprism;

  settings = pkgs.writeTextFile {
    name = "settings";
    destination = "/settings.yml";
    text = "";
  };

in
{
  options.h4ck.photoprism = {
    enable = lib.mkEnableOption "Photoprism";
    port = lib.mkOption {
      type = lib.types.port;
      default = 2342;
    };
  };

  config = lib.mkIf cfg.enable {
    h4ck.backup.paths = [ "/var/lib/photoprism" ];
    systemd.services.photoprism = {
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        coreutils
        darktable
        ffmpeg
        exiftool
        libheif
      ];
      environment = (
        lib.mapAttrs' (n: v: lib.nameValuePair "PHOTOPRISM_${n}" (toString v)) {
          DEBUG = 1;
          DATABASE_DRIVER = "sqlite";
          DATABASE_DSN = "/var/lib/photoprism/photoprism.sqlite";
          DATABASE_CONNS = 256;
          ASSETS_PATH = "${pkgs.photoprism.assets}";
          STORAGE_PATH = "/var/cache/photoprism/";
          ORIGINALS_PATH = "/var/lib/photoprism/originals";
          SIDECAR_JSON = 1;
          SIDECAR_PATH = "/var/lib/photoprism/sidecar";
          CACHE_PATH = "/var/cache/photoprism/cache";
          IMPORT_PATH = "/var/lib/photoprism/import";
          ADMIN_PASSWORD = "admin"; # initial admin passsword, overriden through the settings UI?!
          TEMP_PATH = "/tmp";
          HTTP_PORT = cfg.port;
          SETTINGS_PATH = "${settings}";
        }
      ) // {
        HOME = "/var/cache/photoprism/home"; # darktable because it hardcoded $HOME/.config/darktable
      };
      script = ''
        exec ${pkgs.photoprism}/bin/photoprism start
      '';
      serviceConfig = {
        DynamicUser = true;
        RuntimeDirectory = "photoprism";
        CacheDirectory = "photoprism";
        StateDirectory = "photoprism";
        SyslogIdentifier = "photoprism";
        PrivateTmp = true;
      };
    };
  };
}

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
  };

  config = lib.mkIf cfg.enable {
    systemd.services.photoprism = {
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        coreutils
        darktable
        ffmpeg
        exiftool
        libheif
      ];
      environment = lib.mapAttrs' (n: v: lib.nameValuePair "PHOTOPRISM_${n}" (toString v)) {
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
        TEMP_PATH = "/tmp";
        SETTINGS_PATH = "${settings}";
      };
      script = ''
        # TODO: assets-path must be built from source
        # assets-path/
        #            /examples
        #            /templates/
        #                      /index.tmpl
        #            /static/
        #                   /build
        #                   /img
        #            /nsfw
        #            /nasnet
        exec ${pkgs.photoprism}/bin/photoprism start
      '';
      serviceConfig = {
        DynamicUser = true;

        RuntimeDirectory = "photoprism";
        CacheDirectory = "photoprism";
        StateDirectory = "photoprism";
        PrivateTmp = true;
      };
    };
  };
}

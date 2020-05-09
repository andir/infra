{ config, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption mkOption types;
  cfg = config.h4ck.bird;
in
{
  options.h4ck.bird = {
    enable = mkEnableOption "Enable the bird wrapper module";
    routerId = mkOption {
      type = types.str;
    };
  };
  config = mkIf cfg.enable {
    services.bird2 = {
      enable = true;
      config = ''
        router id ${cfg.routerId};

        protocol direct {
          ipv4;
          ipv6;
          interface "*";
        };

      '';
    };
  };
}

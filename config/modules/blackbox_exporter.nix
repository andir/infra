{ options, pkgs, config, lib, ... }:
let
  cfg = config.h4ck.blackbox_exporter;
in
{
  options.h4ck.blackbox_exporter = {
    config = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
    };
  };
  config.services.prometheus.exporters.blackbox = lib.mkIf (cfg != null) {
    configFile = pkgs.writeText "config.yaml" (builtins.toJSON cfg.config);
  };
}

{ pkgs, lib, config, ... }:
let
  cfg = config.h4ck.compact-matrix-states;
in
{
  options.h4ck = {
    compact-matrix-states = {
      enable = lib.mkEnableOption "Compact the synapse state";
      username = lib.mkOption {
        type = lib.types.str;
        default = "matrix-synapse";
      };

      database_name = lib.mkOption {
        type = lib.types.str;
        default = "matrix-synapse";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.compact-matrix-states = {
      startAt = "daily";
      serviceConfig = {
        User = cfg.username;
        ExecStart =
          let
            pkg = pkgs.compact-matrix-states.override {
              inherit (cfg) username database_name;
              postgresql = config.services.postgresql.package;
            };
          in
          "${pkg}/bin/compact-matrix-states";
      };
    };
  };
}

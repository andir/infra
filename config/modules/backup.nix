{ config, lib, ... }:
let
  cfg = config.h4ck.backup;
in
{
  options.h4ck.backup.paths = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [];
  };
  config.h4ck.backup.paths = [ "/etc/nixos" ];
}

{ lib, config, ... }:
{
  options.h4ck.fqdn = lib.mkOption {
    type = lib.types.str;
    default = null;
  };

  config.h4ck.fqdn = config.networking.hostName + (lib.optionalString (config.networking.domain != null) ".${config.networking.domain}");
}

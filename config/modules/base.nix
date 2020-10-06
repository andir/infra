{ lib, config, ... }:
{
  options.h4ck.fqdn = lib.mkOption {
    type = lib.types.str;
    default = null;
  };

  config = {
    h4ck.fqdn = config.networking.hostName + (lib.optionalString (config.networking.domain != null) ".${config.networking.domain}");

    # FIXME: upstream this change if it turns out to really fix the unbound being unavailable during acme run
    # Can be removed once https://github.com/NixOS/nixpkgs/pull/99901 hits nixos-20.09
    systemd.services.acme-fixperms.after = lib.mkIf (config.systemd.services ? acme-fixperms) [ "nss-lookup.target" ];
  };
}

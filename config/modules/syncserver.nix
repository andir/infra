{ config, lib, ... }:
let
  domain = "syncserver.h4ck.space";
  port = 5001;
in {

  options = {
    h4ck.syncserver = {
      enable = lib.mkEnableOption "Enable sync server";
    };
  };

  config = lib.mkIf config.h4ck.syncserver.enable {
    h4ck.backup.paths = [ "/var/db/firefox-sync-server" ];
    services.firefox.syncserver = {
      enable = true;
      publicUrl = "https://${domain}";
      allowNewUsers = true;
      listen.address = "localhost";
      listen.port = port;
    };
    services.nginx = {
      recommendedProxySettings = true;
      virtualHosts.${domain} = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://localhost:${toString port}";
      };
    };
  };
}


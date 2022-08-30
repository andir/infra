{ config, lib, ... }:
let
  enable = false;
in
{
  services.calibre-web = {
    enable = enable;
    listen = {
      ip = "::1";
      port = 8083;
    };

    options.enableBookUploading = true;
    options.enableBookConversion = true;
    options.calibreLibrary = "/var/lib/calibre-web/books";
  };

  h4ck.backup.paths = lib.mkIf enable [ "/var/lib/calibre-web" ];

  services.nginx.virtualHosts."books.kack.it" = lib.mkIf enable {
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://[::1]:8083/";
      extraConfig = ''
        client_max_body_size 100M;
      '';
    };
  };
}

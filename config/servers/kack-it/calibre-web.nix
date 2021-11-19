{
  services.calibre-web = {
    enable = true;
    listen = {
      ip = "::1";
      port = 8083;
    };

    options.enableBookUploading = true;
    options.enableBookConversion = true;
    options.calibreLibrary = "/var/lib/calibre-web/books";
  };

  h4ck.backup.paths = [ "/var/lib/calibre-web" ];

  services.nginx.virtualHosts."books.kack.it" = {
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

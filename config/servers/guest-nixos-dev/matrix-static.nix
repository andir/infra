{
  h4ck.matrix-static = {
    enable = true;
    homeserverUrl = "https://guest.nixos.dev";
    listenPort = 8000;
  };

  services.nginx.virtualHosts."logs.guest.nixos.dev" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://[::1]:8000";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;'';
    };
  };
}


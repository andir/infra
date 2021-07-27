{
  h4ck.matrix-static = {
    enable = true;
    homeserverUrl = "https://matrix.nixos.dev";
    listenPort = 8000;
  };
  systemd.services.matrix-static.after = [ "matrix-synapse.service" "dex.service" ];

  services.nginx.virtualHosts."logs.nixos.dev" = {
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


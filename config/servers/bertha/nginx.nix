{
  services.nginx = {
    enable = true;
    virtualHosts."epsilon.rammhold.de" = {
      forceSSL = true;
      enableACME = true;
      locations."/weechat" = {
        proxyPass = "https://[fd21:a07e:735e:ff01:ae1f:6bff:fe45:be15]:9001";
        proxyWebsockets = true;
      };
    };
  };
}

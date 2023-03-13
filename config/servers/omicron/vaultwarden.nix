{
  systemd.network.netdevs.vaultwarden.netdevConfig = {
    Kind = "dummy";
    Name = "vaultwarden";
  };
  systemd.network.networks.vaultwarden = {
    matchConfig.Name = "vaultwarden";
    address = [ "127.0.80.1/32" ];
    networkConfig.IPv6AcceptRA = "no";
    DHCP = "no";
  };
  services.vaultwarden = {
    enable = true;
    config = {
      domain = "https://bw.rammhold.de";
      signupsAllowed = false;
      rocketPort = 8222;
      rocketAddress = "127.0.80.1";
      rocketLog = "critical";
      ipHeader = "X-Forwarded-For";
      websocketEnabled = true;
      websocketAddress = "127.0.80.1";
      websocketPort = 8223;
    };
    dbBackend = "sqlite";
    backupDir = "/tank/vaultwarden";
  };

  services.nginx.virtualHosts."bw.rammhold.de" = {
    forceSSL = true;
    enableACME = true;
    locations."/".proxyPass = "http://127.0.80.1:8222";
    locations."/notifications/hub" = {
      proxyPass = "http://127.0.80.1:8223";
      proxyWebsockets = true;
    };
    locations."/notifications/hub/negotiate" = {
      proxyPass = "http://127.0.80.1:8222";
      proxyWebsockets = true;
    };
  };
}

{
  services.gitea = {
    enable = true;
    ssh.enable = true;
    domain = "gitea.rammhold.de";
    rootUrl = "https://gitea.rammhold.de";
    settings.other.SHOW_FOOTER_VERSION = false;
    stateDir = "/tank/gitea/data";
    dump = {
      enable = true;
      interval = "daily";
    };
    disableRegistration = true;
    database = {
      type = "sqlite3";
    };
    cookieSecure = true;

    enableUnixSocket = true;
    # httpAddress = "127.0.0.1";
    # httpPort = 3000;
  };


  services.nginx = {
    enable = true;
    virtualHosts."gitea.rammhold.de" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://unix:/run/gitea/gitea.sock:/";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}

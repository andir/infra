# static content hosting
{
  systemd.tmpfiles.rules = [
    "d /var/lib/s.rammhold.de 750 andi nginx -"
    "d /var/lib/s.h4ck.space 750 andi nginx -"
  ];

  services.nginx = {
    enable = true;
    virtualHosts."s.rammhold.de" = {
      enableACME = true;
      forceSSL = true;
      root = "/var/lib/s.rammhold.de";
    };
    virtualHosts."s.h4ck.space" = {
      enableACME = true;
      forceSSL = true;
      root = "/var/lib/s.h4ck.space";
    };

    virtualHosts."goerigk.rammhold.de" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        return = "302 https://gallery.rammhold.de/s/3ktn78spkw/hochzeit-nils-and-anja";
      };
    };
  };
}

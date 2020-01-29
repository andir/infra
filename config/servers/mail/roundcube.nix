{
  services.roundcube = {
    enable = true;
    hostName = "webmail.h4ck.space";
    database.password = "securepasswordforthelocalhostonlypostgresql";
    plugins = [
      "archive"
      "zipdownload"
      "managesieve"
      "acl"
    ];
  };
  services.nginx.virtualHosts."webmail.h4ck.space" = {
    serverAliases = [ "mail.jh4all.de" "webmail.kack.it" ];
  };

  security.acme.certs."mx.h4ck.space".extraDomains = {
    "mail.jh4all.de" = null;
  };
}

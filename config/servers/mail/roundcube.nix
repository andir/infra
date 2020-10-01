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
    extraConfig = ''
      $config['smtp_server'] = 'tls://mx.h4ck.space';
      $config['smtp_conn_options'] = array(
        'ssl'         => array(
          'verify_peer'  => true,
          'verify_depth' => 3,
          'cafile'       => '/etc/ssl/certs/ca-bundle.crt',
        ),
      );
    '';
  };
  services.nginx.virtualHosts."webmail.h4ck.space" = {
    serverAliases = [ "mail.jh4all.de" "webmail.kack.it" ];
  };

  security.acme.certs."mx.h4ck.space".extraDomainNames = [
    "mail.jh4all.de"
  ];
}

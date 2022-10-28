# static content hosting
{
  systemd.tmpfiles.rules = [
    "d /var/lib/s.rammhold.de 750 andi nginx -"
    "d /var/lib/s.h4ck.space 750 andi nginx -"
    "d /var/lib/dsm.kack.it 750 dsm nginx -"
  ];

  users.groups.dsm = { };
  users.users.dsm = {
    group = "dsm";
    isSystemUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHMDzz4p6UPfKLY5/zaLqGG/CQ+jMgRIEH4H8Iw0Igba"
    ];
    useDefaultShell = true;
  };

  security.acme = {
    certs."s.rammhold.de" = {
      keyType = "rsa4096";
      extraLegoRunFlags = [
        # re: https://community.letsencrypt.org/t/production-chain-changes/150739/1
        # re: https://github.com/ipxe/ipxe/pull/116
        # re: https://github.com/ipxe/ipxe/pull/112
        # re: https://lists.ipxe.org/pipermail/ipxe-devel/2020-May/007042.html
        "--preferred-chain"
        "ISRG Root X1"
      ];
      extraLegoRenewFlags = [
        # re: https://community.letsencrypt.org/t/production-chain-changes/150739/1
        # re: https://github.com/ipxe/ipxe/pull/116
        # re: https://github.com/ipxe/ipxe/pull/112
        # re: https://lists.ipxe.org/pipermail/ipxe-devel/2020-May/007042.html
        "--preferred-chain"
        "ISRG Root X1"
      ];
    };
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    #sslProtocols = "TLSv1.2";
    sslCiphers = "DEFAULT:AES256-SHA256";
    virtualHosts."kack.it" = {
      locations."/".extraConfig = ''
        add_header Content-Type text/plain;
        return 200 'Probably broken.';
      '';
    };
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
    virtualHosts."dsm.kack.it" = {
      enableACME = true;
      forceSSL = true;
      root = "/var/lib/dsm.kack.it";
    };

    virtualHosts."goerigk.rammhold.de" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        return = "302 https://gallery.rammhold.de/s/20wynykmzl/hochzeit-nils-and-anja";
      };
    };
  };
}

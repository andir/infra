{ lib, config, pkgs, ... }:
let
  cfg = config.services.vsftpd;
  dataDir = "/var/lib/vsftpd";
  users.user = "$6$Xj63tIQvvEslm$qqXUzopknR5dK0PLDAfnmV7UzS/hovpPozXP4MPQ9dYwUj3q6Z4ItoY6CupJMG4dY9OjqxVTU1iHRtSxbuwjG.";

  pasv_min_port = 15300;
  pasv_max_port = 15400;

in
{
  services.vsftpd = {
    enable = true;
    writeEnable = true;
    localUsers = true;
    virtualUseLocalPrivs = true;
    userlist = [ "user" ];
    enableVirtualUsers = true;
    forceLocalLoginsSSL = false;
    forceLocalDataSSL = false;
    localRoot = dataDir + "/$USER";
    rsaCertFile = config.security.acme.certs."gallery.rammhold.de".directory + "/cert.pem";
    rsaKeyFile = config.security.acme.certs."gallery.rammhold.de".directory + "/key.pem";

    userDbPath = let
      plainUsersDb = pkgs.writeText "vwftpd-plain-user-db" (lib.concatStrings (lib.attrValues (lib.mapAttrs (user: password: "${user}\n${password}\n") users)));
      bdb = pkgs.runCommand "vsftpd-user-db" { buildInputs = [ pkgs.db ]; } ''
        cp ${plainUsersDb} logins.txt
        cat logins.txt
        mkdir $out
        db_load -T -t hash -f logins.txt $out/logins.db
      '';
    in
      toString (bdb + "/logins");


    extraConfig = ''
      debug_ssl=YES
      user_sub_token=$USER
      pasv_enable=YES
      pasv_min_port=${toString pasv_min_port}
      pasv_max_port=${toString pasv_max_port}
    '';
  };
  # The module in NixOS doesn't support storing crypted logins yet.
  # Just force it for now until I get around to make a PR.
  security.pam.services.vsftpd.text = lib.mkForce ''
    auth required pam_userdb.so db=${cfg.userDbPath} crypt=crypt
    account required pam_userdb.so db=${cfg.userDbPath} crypt=crypt
  '';

  systemd.tmpfiles.rules = lib.attrValues (lib.mapAttrs (user: password: "d ${dataDir}/${user}/data 0750 vsftpd -") users);

  h4ck.backup.paths = [
    dataDir
  ];

  networking.firewall.allowedTCPPorts = lib.genList (x: pasv_min_port + x) (pasv_max_port - pasv_min_port);

  # Canon 5D Mark4 doesn't support anything newer :'(
  security.acme.certs."gallery.rammhold.de".keyType = "rsa4096";

}

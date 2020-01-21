{ 
  services.roundcube = {
    enable = true;
    hostName = "webmail.kack.it";
    database.password = "securepasswordforthelocalhostonlypostgresql";
    plugins = [
      "archive"
      "zipdownload"
      "managesieve"
      "acl"
    ];
  };
}

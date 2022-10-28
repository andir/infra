{
  users.groups.zrepl-clients = { };
  users.users.zeta-backups = {
    isSystemUser = true;
    openssh.authorizedKeys.keys = [
      ''
        command="zrepl stdinserver zeta",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIli6KfN92fAn4D6aSCwwB0jmRZqPcQdtvxj5aIcj95L root@zeta
      ''
    ];
    group = "zrepl-clients";
    useDefaultShell = true;
  };
  services.zrepl = {
    enable = true;
    settings = {
      jobs = [
        {
          name = "zeta-to-omicron";
          type = "sink";
          recv = {
            properties."inherit" = [
              "encryption"
              "compression"
            ];
            placeholder.encryption = "inherit";
          };
          serve = {
            type = "stdinserver";
            client_identities = [
              "zeta"
            ];
          };
          root_fs = "tank/backups/zrepl";
        }
      ];
    };
  };

  systemd.services.zrepl.postStart = ''
    set -ex
    sleep 15
    chown zeta-backups /var/run/zrepl/stdinserver/zeta
    chmod go+rX /var/run/zrepl/stdinserver
    chmod go+rX /var/run/zrepl/
  '';
}

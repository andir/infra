{
  h4ck.dendrite = {
    enable = true;
    serverName = "kack.it";
    nginxVhost = "matrix.kack.it";
    disableFederation = false;
  };

  services.nginx.virtualHosts."matrix.kack.it" = {
    enableACME = true;
    forceSSL = true;
  };
  mods.hetzner.vm.persistentDisks."/var/lib/private/dendrite".id = 9954962;
  h4ck.backup.paths = [ "/var/lib/private/dendrite" ];
}

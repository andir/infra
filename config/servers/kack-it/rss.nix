{ config, pkgs, ... }:
{
  deployment.secrets."miniflux" = {
    source = "../secrets/miniflux.env";
    destination = "/var/secrets/miniflux.env";
  };
  services.miniflux = {
    enable = true;
    adminCredentialsFile = "/var/secrets/miniflux.env";
    config = {
      LISTEN_ADDR = "localhost:8181";
    };
  };
  services.nginx = {
    enable = true;
    virtualHosts."rss.rammhold.de" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://localhost:8181";
      };
      locations."/lwn" = {
        proxyPass = "http://localhost:8282";
        extraConfig =
          let
            htpasswd = pkgs.writeText "htpasswd" ''
              cioupaoisv:$6$TS.uEVGRdaMzuhMc$6ZNENO4AEZ8nT7hxcabbGoCmj5IIWkKz4yOacX.8oHMmBsVzg3jg.bSrSkmNawWBdF8PY74Q/MTBxVLazycOo/
              ochahWeegh8soox:$6$yl3kuU6bMCFrN3Ni$druWekTF12jUPUFf2nDK6MDi595obt/0i8kLHSUzU9huZBCo6VArSK1srvctkIraYHk6UjdyAELeyzBuucZb70
              Drowsily0545:$6$rc86K4BOyb6FgTqJ$u.3V1bjoKOhKKFWQl40u4PGjSZ4Qfs2G/o3v7LV4Rve8W.Q/jhbD2G471EAWLaZFiddJzv7w6Lw2Fm0BuI4QS1
            '';
          in
          ''
            auth_basic           "closed site";
            auth_basic_user_file ${htpasswd};
          '';
      };
    };
  };

  systemd.services.lwnfeed = {
    wantedBy = [ "multi-user.target" ];
    script = ''
      echo $PWD
      ls -la 
      ${pkgs.lwnfeed}/bin/lwnfeed -f lwnfeed.cookie.gob start -l :8282 -c feed.cache
    '';
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "lwnfeed";
      WorkingDirectory = "/var/lib/lwnfeed";
    };
  };
}

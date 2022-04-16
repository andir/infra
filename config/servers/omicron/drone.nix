{ lib, config, pkgs, ... }:
let
  droneserver = config.users.users.droneserver.name;
  drone-runner-docker = config.users.users.drone-runner-docker.name;
in
{

  deployment.secrets."drone-gitea-secrets" = {
    source = "../secrets/drone-gitea-secrets";
    destination = "/var/lib/secrets/drone-gitea-secrets";
    owner.user = droneserver;
    action = [ "sudo" "systemctl" "restart" "drone-server" ];
  };


  systemd.services.drone-server-secret = {
    before = [ "drone-server.service" "drone-runner-docker.service" ];
    wantedBy = [ "drone-server.service" ];
    script = ''
      if ! test -e /var/lib/secrets/drone-server; then
        SECRET=$(tr -dc A-Za-z0-9 </dev/urandom 2>/dev/null | head -c 64)
        echo "DRONE_RPC_SECRET=''${SECRET}"> /var/lib/secrets/drone-server
      fi

      chown ${droneserver}: /var/lib/secrets/drone-server
      cp /var/lib/secrets/drone-server /var/lib/secrets/drone-runner-docker
      chown ${drone-runner-docker}: /var/lib/secrets/drone-runner-docker
    '';
  };
  systemd.services.drone-server = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = [
        "/var/lib/secrets/drone-server"
        "/var/lib/secrets/drone-gitea-secrets"
      ];
      Environment = [
        "DRONE_GITEA_SERVER=https://gitea.rammhold.de"
        "DRONE_SERVER_HOST=drone.rammhold.de"
        "DRONE_SERVER_PROTO=https"
        "DRONE_USER_CREATE=username:andi,admin:true"
        "DRONE_DATABASE_DRIVER=sqlite3"
        "DRONE_DATABASE_DATASOURCE=/tank/drone/database.sqlite"
      ];
      ExecStart = "${pkgs.drone}/bin/drone-server";
      User = droneserver;
      Group = droneserver;
    };
  };

  virtualisation.docker = {
    enable = true;
    package = pkgs.docker.override {
      moby-src = pkgs.runCommand "moby-src-patched"
        {
          src = pkgs.docker.moby-src;
          patch =
            (pkgs.fetchpatch {
              url = "https://github.com/moby/moby/commit/ee9e52676409b2e428a816ac59f42f5ba61089dd.patch";
              sha256 = "1si0k9gc1j2gc8q8f7w8zmn3mc65djyfyyhsxbmj418lprkqgrlc";
            })
          ;
        } ''
        cp -rv $src $out
        chmod -R +rw $out
        cd $out/vendor/github.com/docker/
        patch -p1 < $patch || : # there is a file missing in the old source, ignore it for now...
      '';
    };
    storageDriver = "zfs";
    autoPrune.enable = true;
    extraOptions = "--default-address-pool base=100.64.0.0/16,size=24";
  };

  systemd.services.drone-runner-docker = {
    wantedBy = [ "multi-user.target" ];
    after = [ "dockerd.service" ];
    path = [ pkgs.drone-runner-docker ];
    serviceConfig = {
      EnvironmentFile = [
        "/var/lib/secrets/drone-runner-docker"
      ];
      Environment = [
        "DRONE_RPC_PROTO=https"
        "DRONE_RPC_HOST=drone.rammhold.de"
        "DRONE_RUNNER_CAPACITY=2"
        "DRONE_RUNNER_NAME=omicron"
      ];
      User = "drone-runner-docker";
      Group = "drone-runner-docker";
    };
    script = ''
      exec drone-runner-docker
    '';
  };

  # systemd.services.drone-runner-exec = {
  #   wantedBy = [ "multi-user.target" ];
  #   path = [ pkgs.drone-runner-exec ];
  #   serviceConfig = {
  #     EnvironmentFile = [
  #       "/var/lib/secrets/drone-runner-exec"
  #     ];
  #     Environment = [
  #       "DRONE_RPC_PROTO=https"
  #       "DRONE_RPC_HOST=drone.rammhold.de"
  #       "DRONE_RUNNER_CAPACITY=2"
  #       "DRONE_RUNNER_NAME=omicron"
  #     ];
  #     User = "drone-runner-exec";
  #     Group = "drone-runner-exec";
  #     RuntimeDirectory = "drone-runner-exec";
  #   };
  #   script = ''
  #     exec drone-runner-exec
  #   '';

  # };

  services.nginx.virtualHosts."drone.rammhold.de" = {
    enableACME = true;
    forceSSL = true;
    locations."/".extraConfig = ''
      proxy_pass http://localhost:8080;
    '';
  };

  users.users.droneserver = {
    isSystemUser = true;
    createHome = true;
    group = droneserver;
  };
  users.groups.droneserver = { };

  users.users.drone-runner-docker = {
    isSystemUser = true;
    createHome = false;
    group = "drone-runner-docker";
    extraGroups = [ "docker" ];
  };
  users.groups.drone-runner-docker = { };
}

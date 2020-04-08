{ config, pkgs, ... }:
let
  home = "/var/lib/blog";

  env = pkgs.buildEnv {
    name = "post-receive-env";
    paths = [
      pkgs.git
      pkgs.nix
      pkgs.coreutils
      pkgs.gnutar
      pkgs.xz
    ];
  };

  post-receive = pkgs.writeShellScript "post-receive" ''
    export PATH=${env}/bin
    set -ex

    GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
    if [ -z "$GIT_DIR" ]; then
            echo >&2 "fatal: post-receive: GIT_DIR not set"
            exit 1
    fi


    TMPDIR=$(mktemp -d)
    function cleanup() {
      rm -rf "$TMPDIR"
    }
    trap cleanup EXIT

    git clone "$GIT_DIR" "$TMPDIR"
    unset GIT_DIR
    cd "$TMPDIR"
    exec nix-build "$TMPDIR" -A build -o ${home}/current
  '';


in
{
  config = {
    services.nginx.virtualHosts."andreas.rammhold.de" = {
      enableACME = true;
      forceSSL = true;
      root = "/var/lib/blog/current";
    };
    users.users.blog = {
      inherit home;
      createHome = true;
      isNormalUser = true;
      openssh = config.users.users.andi.openssh;
      packages = [ pkgs.git pkgs.nix ];
    };

    systemd.services."blog-prepare-git-repo" = {
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.git
      ];
      script = ''
        set -ex
        cd ${home}
        chmod +rX ${home} # no secrets in that home dir, everyone can read my public blog
        test -e repo || git init --bare repo
        ln -nsf ${post-receive} repo/hooks/post-receive
      '';
      serviceConfig = {
        Kind = "one-shot";
        User = "blog";
      };
    };
  };
}

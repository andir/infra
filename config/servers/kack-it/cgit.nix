{ pkgs, config, ... }:
let
  cgitrc = ''
    enable-git-config=1
    remove-suffix=1
    section-from-path=1
    cache-size=1000

    source-filter=${pkgs.cgit}/lib/cgit/filters/syntax-highlighting.py
    about-filter=${pkgs.cgit}/lib/cgit/filters/about-formatting.sh
    root-title=Public Projects
    root-desc=All my public projects.

    snapshots=tar.gz zip

    # Make packages cloneable
    clone-url=https://git.rammhold.de/$CGIT_REPO_URL

    # hide my name in index
    enable-index-owner=0

    # for look and feel
    enable-index-links=1
    enable-blame=1
    enable-commit-graph=1
    enable-follow-links=1
    enable-log-filecount=1
    enable-log-linecount=1
    branch-sort=age
    noplainemail=1
    side-by-side-diffs=1

    ##
    ## List of common mimetypes
    ##

    mimetype.gif=image/gif
    mimetype.html=text/html
    mimetype.jpg=image/jpeg
    mimetype.jpeg=image/jpeg
    mimetype.pdf=application/pdf
    mimetype.png=image/png
    mimetype.svg=image/svg+xml

    ## Search for these files in the root of the default branch of repositories
    ## for coming up with the about page:

    readme=:README.md
    readme=:readme.md
    readme=:README
    readme=:readme

    project-list=/var/lib/repositories/projects.list
    scan-path=/var/lib/repositories
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /var/cache/cgit 0700 cgit cgit"
    "d /var/lib/repositories 0750 andi cgit"
  ];

  users.users.cgit = {
    isSystemUser = true;
    group = "cgit";
  };
  users.groups.cgit = { };

  services.fcgiwrap = {
    enable = true;
    user = "cgit";
    group = "cgit";
  };

  services.nginx.virtualHosts."git.rammhold.de" = {
    forceSSL = true;
    enableACME = true;

    locations = {
      "~* ^.+\.(css|png|ico)$" = {
        root = "${pkgs.cgit}/cgit";
      };
      "/" = {
        extraConfig = ''
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_param CGIT_CONFIG ${pkgs.writeText "cgitrc" cgitrc};
          fastcgi_param SCRIPT_FILENAME ${pkgs.cgit}/cgit/cgit.cgi;
          fastcgi_split_path_info ^(/?)(.+)$;
          fastcgi_param PATH_INFO $fastcgi_path_info;
          fastcgi_param QUERY_STRING $args;
          fastcgi_param HTTP_HOST $server_name;
          fastcgi_pass unix:${config.services.fcgiwrap.socketAddress};
        '';
      };
    };
  };

  environment.systemPackages = [
    pkgs.gitMinimal
    (pkgs.writeShellScriptBin "create-repository" ''
      PATH="${pkgs.gitMinimal}/bin:$PATH"
      set -o pipefail
      set -ex
      if [ "$#" -lt 1 ]; then
        echo "Missing repo name"
        exit 1
      fi

      test -d "/var/lib/repositories/$1.git" || git init --bare "/var/lib/repositories/$1.git"
      grep "$1.git" /var/lib/repositories/projects.list || echo "$1.git" >> /var/lib/repositories/projects.list
      echo "$ git add remote kack.it $USER@kack.it:/var/lib/repositories/$1.git"
      exit 0
    '')
  ];
}

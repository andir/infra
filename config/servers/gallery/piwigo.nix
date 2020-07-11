{ pkgs, lib, ... }:
# FIXME: piwigo should be tracked by niv but niv doesn't support tracking releases yet :/
let
  version = "2.11.0beta1";
  sha256 = "1avybxkrv46c8alxy256gvdh648nhbajmrpz4gflcn914b5kvrd7";
  src = pkgs.fetchFromGitHub {
    owner = "Piwigo";
    repo = "Piwigo";
    rev = version;
    inherit sha256;
  };

  theme = pkgs.fetchzip {
    url = "https://github.com/tkuther/piwigo-bootstrap-darkroom/archive/2.4.4.zip";
    sha256 = "0ki25sbj69x9j4isgy4cwrjlcfdk58pyi268k5fxpd1w3f7v3sxm";
  };

  dbConfig = pkgs.writeTextFile {
    name = "config";
    destination = "/local/config/config.inc.php";
    text = ''
      <?php
      $conf['dblayer'] = 'mysqli';
      $conf['db_base'] = 'gallery.rammhold.de';
      $conf['db_user'] = 'gallery_rammhold_de';
      $conf['db_password'] = "";
      $conf['db_host'] = 'localhost';
      $prefixeTable = 'piwigo_';

      define('PHPWG_INSTALLED', true);
      define('PWG_CHARSET', 'utf-8');
      define('DB_CHARSET', 'utf8');
      define('DB_COLLATE', "");


      // paths must be relative to the nix store root of the application
      // $conf['data_location'] = '../../../data/piwigo/_data/';
      // $conf['upload_dir'] = '../../../data/piwigo/upload';
      ?>
    '';
  };

  /*
  webroot = pkgs.symlinkJoin {
    name = "piwigo-${version}";
    paths = [
      src
      dbConfig
    ];

    postBuild = ''
      ln -s /data/piwigo/_data _data
      ln -s /data/piwigo/upload upload
    '';
  };
  */
  webroot = pkgs.runCommand "webroot-${version}" {} ''
    cp -rv ${src} $out
    chmod +rw -R $out
    cp -rv ${dbConfig}/local/config/* $out/local/config/.
    ln -s ${theme} $out/themes/bootstrap_darkroom
    ln -s /data/piwigo/_data $out/_data
    ln -s /data/piwigo/upload $out/upload
  '';

in
{
  mods.webhost.virtualHosts = {
    "gallery.rammhold.de" = {
      application = "wordpress";
      documentRoot = let p = ./piwigo.nix; in assert (builtins.isPath p); p; # hack to workaround wonky path handling in the webhost mod
    };
  };
  services.nginx.virtualHosts."gallery.rammhold.de" = {
    root = lib.mkForce webroot;
    #    locations."data/piwigo/_data".root = "/data/piwigo/_data";
  };

  systemd.tmpfiles.rules = [
    "d /data/piwigo/_data 770 gallery_rammhold_de gallery_rammhold_de -"
    "d /data/piwigo/upload 770 gallery_rammhold_de gallery_rammhold_de -"
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  environment.etc."sources/piwigo".source = src;
}

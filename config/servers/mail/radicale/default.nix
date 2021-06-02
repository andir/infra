{ config, lib, pkgs, ... }:
let
  radicale_auth_crypt = pkgs.python3.pkgs.buildPythonPackage {
    pname = "radicale_auth_crypt";
    version = "0.0";
    src = ./radicale_auth_crypt;
    checkInputs = [
      pkgs.radicale3
    ];
  };
in
{

  users.users.radicale = {
    home = "/var/lib/radicale";
    createHome = true;
    isSystemUser = true;
  };
  services.radicale = {
    enable = true;
    package = pkgs.radicale3.overrideAttrs (
      { propagatedBuildInputs, ... }: {
        propagatedBuildInputs = propagatedBuildInputs ++ [
          radicale_auth_crypt
        ];
      }
    );
    settings = {
      server.hosts = "127.0.0.1:5232";

      auth = {
        delay = 1;
        type = "radicale_auth_crypt";
        htpasswd_filename = builtins.toFile "passwd" (lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${name}:${value.hashedPassword}") config.mailserver.loginAccounts));
        # htpasswd_encryption = crypt
      };

      storage = {
        filesystem_folder = config.users.users.radicale.home;
        # hook = git add -A && (git diff --cached --quiet || git commit -m "Changes by "%(user)s)
      };
    };
  };

  services.nginx = {
    virtualHosts."davical.h4ck.space" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:5232";
    };
  };

  networking.firewall.allowedTCPPorts = [ 443 ];
}

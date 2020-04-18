{ config, lib, ... }: {
  services.radicale = {
    enable = true;
    config = ''
      [server]
      hosts = 127.0.0.1:5232

      [auth]
      delay = 1
      type = htpasswd
      htpasswd_filename = ${builtins.toFile "passwd" (lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${name}:${value.hashedPassword}") config.mailserver.loginAccounts)) }
      htpasswd_encryption = crypt

      [storage]
      filesystem_folder = ${config.users.users.radicale.home}
      # hook = git add -A && (git diff --cached --quiet || git commit -m "Changes by "%(user)s)
    '';
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

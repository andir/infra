{ config, lib, pkgs, ... }:
let
  snms = (builtins.fetchTarball {
    url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/v2.3.0/nixos-mailserver-v2.3.0.tar.gz";
    sha256 = "0lpz08qviccvpfws2nm83n7m2r8add2wvfg9bljx9yxx8107r919";
  });

  # import secrets if they exist (e.g. on deployment hosts)
  secrets =
    let
      path = ../../secrets/mail.nix;
      default = {
        domains = [];
        loginAccounts = {};
      };
    in if builtins.trace path builtins.pathExists path then import path else default;

in {

  imports = [
    snms
    ../profiles/hetzner-vm.nix
  ];

  deployment = {
    targetHost = "test-mx.kack.it.";
    targetUser = "morph";
    substituteOnDestination = true;
  };

  fileSystems."/".fsType = "btrfs";
  mods.hetzner = {
    networking.ipAddresses = [
      "159.69.146.50/32"
      "2a01:4f8:1c1c:f2f5::/128"
    ];
  };

  # snms provides kresd configuration, pull this in when that isn't the case (anymore?)
  services.unbound.enable = !config.services.kresd.enable;

  mailserver = {
    enable = true;
    fqdn = "test-mx.kack.it";
    domains = [
      "kack.it"
      "foo.bar.kack.it"
    ] ++ secrets.domains;
    loginAccounts = {
        "andi@kack.it" = {
	    hashedPassword = "$6$oJhcZDZZ$9QFwPXZhmjPjJL0TcEsZVTehhdWFxxjVDBDg0Ked71ziAd1GnsJJUpsuIhqG8fdAhalQe/BXn8VZE4Te7oE7g/";

            aliases = [
		"test@kack.it"
            ];
        };
    } // secrets.loginAccounts;

    # Use Let's Encrypt certificates. Note that this needs to set up a stripped
    # down nginx and opens port 80.
    certificateScheme = 3;

    # Enable IMAP and POP3
    enableImap = true;
    enablePop3 = false;
    enableImapSsl = true;
    enablePop3Ssl = false;

    # Enable the ManageSieve protocol
    enableManageSieve = true;

    # whether to scan inbound emails for viruses (note that this requires at least
    # 1 Gb RAM for the server. Without virus scanning 256 MB RAM should be plenty)
    virusScanning = true;
  };

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

  services.radicale = {
    enable = true;
    config = ''
      [server]
      hosts = 127.0.0.1:5232

      [auth]
      delay = 1
      type = htpasswd
      htpasswd_filename = ${builtins.toFile "passwd" (lib.concatStringsSep "\n" (lib.mapAttrsToList  (name: value: "${name}:${value.hashedPassword}") config.mailserver.loginAccounts)) }
      htpasswd_encryption = crypt

      [storage]
      filesystem_folder = ${config.users.users.radicale.home}
      # hook = git add -A && (git diff --cached --quiet || git commit -m "Changes by "%(user)s)
    '';
  };

  services.nginx = {
    virtualHosts."davical.kack.it" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://127.0.0.1:5232";
    };
  };

  networking.firewall.allowedTCPPorts = [ 443 ];
}

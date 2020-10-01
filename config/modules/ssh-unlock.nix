{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.h4ck.ssh-unlock;
  haveV4 = cfg.networking.ipv4.address != null;
  haveV6 = cfg.networking.ipv6.address != null;
  haveV4Route = cfg.networking.ipv4.gateway != null;
  haveV6Route = cfg.networking.ipv6.gateway != null;

  hostKeysPath = "/var/lib/initrd-ssh-hostkeys";
  emptySecret = pkgs.writeText "dummy" "";
  postUploadCommands = pkgs.writeShellScript "generate-initrd-ssh-host-keys" ''
    # ${emptySecret} -- keep it in the closure
    mkdir -p ${hostKeysPath}
    chown root:root ${hostKeysPath}
    chmod 700 ${hostKeysPath}
    test -f ${hostKeysPath}/ssh_host_rsa.key || ${pkgs.openssh}/bin/ssh-keygen -t rsa -N "" -f ${hostKeysPath}/ssh_host_rsa.key
    test -f ${hostKeysPath}/ssh_host_ed25519.key || ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${hostKeysPath}/ssh_host_ed25519.key
  '';
in
{
  options.h4ck.ssh-unlock = {
    enable = mkEnableOption "Enabel unlocking the host via SSH";
    networking.ipv6Address = mkOption {
      type = types.nullOr types.str;
      description = "Public IPv6 address that should be assigned in the initrd.";
    };
    networking.interface = mkOption {
      type = types.str;
      default = "eth0";
    };
    networking.ipv4 = {
      address = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Public IPv4 address that should be assigned in the initrd.";
      };
      gateway = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Public IPv4 address that should be assigned in the initrd.";
      };
    };
    networking.ipv6 = {
      address = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Public IPv6 address that should be assigned in the initrd.";
      };
      gateway = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Public IPv6 address that should be assigned in the initrd.";
      };
    };
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [];
    };
  };

  config = mkIf cfg.enable (
    {
      system.activationScripts.initrd-ssh-host-keys = "${postUploadCommands}";
      deployment.secrets."initrd-ssh-host-keys" = {
        source = toString (emptySecret);
        destination = "/var/lib/secrets/initrd-ssh-host-keys-uploaded";
        action = [ "sudo" (toString postUploadCommands) ];
      };

      #assert haveV4 || haveV6;
      boot.initrd = {
        kernelModules = [ "ipv6" ];
        preLVMCommands = mkOrder 490 ''
          hasNetwork=1
        '';
        network = {
          enable = true;
          postCommands = ''
            ip link set up "${cfg.networking.interface}"
          '' + optionalString (haveV4) ''
            ip addr add "${cfg.networking.ipv4.address}" dev "${cfg.networking.interface}"
          '' + optionalString (haveV6) ''
            ip addr add "${cfg.networking.ipv6.address}" dev "${cfg.networking.interface}"
          '' + optionalString (haveV4 && haveV4Route) ''
            ip -4 route add default via "${cfg.networking.ipv4.gateway}" dev "${cfg.networking.interface}"
          '' + optionalString (haveV6 && haveV6Route) ''
            ip -6 route add default via "${cfg.networking.ipv6.gateway}" dev "${cfg.networking.interface}"
          '' + ''
            ip link
            ip -6 a
            ip -4 a
            ip -4 route
            ip -6 route
          '';

          ssh = {
            enable = true;
            authorizedKeys = cfg.authorizedKeys;
            hostKeys = [
              (hostKeysPath + "/ssh_host_rsa.key")
              (hostKeysPath + "/ssh_host_ed25519.key")
            ];
          };
        };
      };
    }
  );
}

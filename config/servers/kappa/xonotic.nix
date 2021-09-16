{ pkgs, ... }:
let
  configFile = ./xonotic.cfg;
in
{
  networking.firewall.allowedTCPPorts = [ 26000 ];
  networking.firewall.allowedUDPPorts = [ 26000 ];

  systemd.services.xonotic-server = {
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.xonotic-dedicated
    ];
    script = ''
      cd $RUNTIME_DIRECTORY
      exec xonotic-dedicated -developer -userdir $STATE_DIRECTORY -sessionid wanparty +serverconfig ${configFile}
    '';
    serviceConfig = {
      DynamicUser = true;
      RuntimeDirectory = "xonotic-server";
      StateDirectory = "xonotic-server";
    };
  };
}

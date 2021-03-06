{ lib, config, pkgs, ... }:
{
  services.nginx = {
    recommendedGzipSettings = lib.mkDefault true;
    recommendedOptimisation = lib.mkDefault true;
    recommendedTlsSettings = lib.mkDefault true;
  };

  services.logrotate = {
    enable = config.services.nginx.enable;
    # For >= 20.09
    paths = lib.mkIf config.services.nginx.enable {
      nginx = {
        path = "/var/log/nginx/*.log";
        user = config.services.nginx.user;
        group = config.services.nginx.group;
        keep = 30;
        frequency = "daily";
        extraConfig = ''
          compress
        '';
      };
    };
  };
}

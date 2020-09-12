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
    #paths = lib.mkIf config.nginx.enable {
    #  nginx = {
    #    path = "/var/spool/nginx/logs";
    #    user = config.services.nginx.user;
    #    group = config.services.nginx.group;
    #    keep = 30;
    #    frequency = "daily";
    #    extraConfig = ''
    #      compress
    #    '';
    #  };
    #};
    config = ''
      "/var/spool/nginx/logs/*.log" {
        su ${config.services.nginx.user} ${config.services.nginx.group}
        daily
        rotate 30
        delaycompress
        compress
        missingok
        notifempty
        postrotate
          ${pkgs.systemd}/bin/systemctl reload nginx
        endscript
      }
    '';
  };
}

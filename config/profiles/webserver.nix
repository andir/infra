{ lib, config, pkgs, ... }:
{
  services.nginx = {
    # Opt-out of the Google FLoC crap
    commonHttpConfig = ''
      add_header Permissions-Policy "interest-cohort=()";
    '';
    recommendedGzipSettings = lib.mkDefault true;
    recommendedOptimisation = lib.mkDefault true;
    recommendedTlsSettings = lib.mkDefault true;
  };

  services.logrotate = {
    enable = config.services.nginx.enable;
    # For >= 20.09
    settings = lib.mkIf config.services.nginx.enable {
      # "/var/log/nginx/*.log" = {
      #   user = config.services.nginx.user;
      #   group = config.services.nginx.group;
      #   keep = 30;
      #   frequency = "daily";
      #   compress = "";
      # };
    };
  };
}

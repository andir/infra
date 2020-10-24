{ pkgs, config, ... }:
{
  services.nginx.virtualHosts."gallery.rammhold.de" = {
    locations."/test-login/" = {
      alias = "${./login}/";
    };
  };
}

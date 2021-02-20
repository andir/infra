{ pkgs, ... }:
{
  services.home-assistant = {
    enable = true;
    autoExtraComponents = false;

    package = pkgs.home-assistant.override {
      extraComponents = [
        "frontend"
        "http"
        "zha"
        "prometheus"
        "system_health"
        "lovelace"
      ];
    };

    config = {
      homeassistant = {
        name = "Home";
        latitude = "49.872707";
        longitude = "8.650689";
        elevation = "140";
        unit_system = "metric";
        time_zone = "Europe/Berlin";
        auth_providers = [
          {
            type = "trusted_networks";
            trusted_networks = [
              "172.20.24.0/23"
              "fd21:a07e:735e::/48"
              "::1"
              "127.0.0.0/8"
            ];
            allow_bypass_login = true;
          }
        ];
      };
      frontend = {
        themes = "!include_dir_merge_named themes";
      };
      http = { };
      zha = {
        database_path = "/var/lib/hass/zha.database";
        zigpy_config = { };
      };
      prometheus = {
        namespace = "epsilon";
        filter.include_entity_globs = "sensor.lumi_lumi_weather_*";
      };
    };

    lovelaceConfig = {
      title = "My Awesome Home";
      views = [
        {
          title = "Environment";
          cards = [
            {
              type = "entities";
              title = "Livingroom";
              entities = [
                "sensor.lumi_lumi_weather_189d7f05_humidity"
                "sensor.lumi_lumi_weather_189d7f05_pressure"
                "sensor.lumi_lumi_weather_189d7f05_temperature"
                "sensor.lumi_lumi_weather_189d7f05_power"
              ];
            }
          ];
        }
        {
          title = "Configuration";
          cards = [
            {
              type = "markdown";
              title = "Markdown Card";
              content = ''
                This config:
                ```nix
                ${builtins.readFile ./hass.nix}
                ```
              '';
            }
          ];
        }
      ];
    };
  };
}

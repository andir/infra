{ pkgs, ... }:
{
  # for updating the conbee II firmware via the deconz image:
  # mkdir /tmp/test
  # docker run  --rm --privileged  -v /tmp/test:/root/.local/share/dresden-elektronik/deCONZ --device=/dev/ttyACM0 --entrypoint /firmware-update.sh -it marthoc/deconz
  virtualisation.docker.enable = true;
  services.home-assistant = {
    enable = true;
    autoExtraComponents = false;

    package = (pkgs.home-assistant.override {
      extraComponents = [
        "frontend"
        "http"
        "zha"
        "prometheus"
        "system_health"
        "lovelace"
      ];
    }).overridePythonAttrs (_: {
      doCheck = false;
    });

    config = {
      logger = {
        default = "info";
        # logs = {
        #   "homeassistant.core" = "debug";
        #   "homeassistant.components.zha" = "debug";
        #   "bellows.zigbee.application" = "debug";
        #   "bellows.ezsp" = "debug";
        #   zigpy = "debug";
        #   zigpy_cc = "debug";
        #   "zigpy_deconz.zigbee.application" = "debug";
        #   "zigpy_deconz.api" = "debug";
        #   "zigpy_xbee.zigbee.application" = "debug";
        #   "zigpy_xbee.api" = "debug";
        #   zigpy_zigate = "debug";
        #   zigpy_znp = "debug";
        #   zhaquirks = "debug";
        # };
      };
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
        enable_quirks = true;
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

            {
              type = "entities";
              title = "Balcony";
              entities = [
                "sensor.lumi_lumi_weather_humidity"
                "sensor.lumi_lumi_weather_pressure"
                "sensor.lumi_lumi_weather_temperature"
                "sensor.lumi_lumi_weather_power"
              ];
            }

            {
              type = "entities";
              title = "Kitchen";
              entities = [
                "sensor.lumi_lumi_weather_75648a05_humidity"
                "sensor.lumi_lumi_weather_75648a05_pressure"
                "sensor.lumi_lumi_weather_75648a05_temperature"
                "sensor.lumi_lumi_weather_75648a05_power"
              ];
            }
            {
              type = "entities";
              title = "Bedroom";
              entities = [
                "sensor.lumi_lumi_weather_10cc8805_humidity"
                "sensor.lumi_lumi_weather_10cc8805_pressure"
                "sensor.lumi_lumi_weather_10cc8805_temperature"
                "sensor.lumi_lumi_weather_10cc8805_power"
              ];
            }

            {
              type = "entities";
              title = "Bathroom";
              entities = [
                "sensor.lumi_lumi_weather_b6ce8805_humidity"
                "sensor.lumi_lumi_weather_b6ce8805_pressure"
                "sensor.lumi_lumi_weather_b6ce8805_temperature"
                "sensor.lumi_lumi_weather_b6ce8805_power"
              ];
            }
            {
              type = "entities";
              title = "Powerplug";
              entities = [
                "sensor.lumi_lumi_plug_maeu01_ce40823c_electrical_measurement"
                "switch.lumi_lumi_plug_maeu01_ce40823c_on_off"
                "sensor.lumi_lumi_plug_maeu01_ce40823c_smartenergy_metering"
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

{ lib, pkgs, ... }: {

  imports = [
    ./dining_table_movement_light.nix
  ];

  services.home-assistant = {
    enable = true;
    package = (pkgs.home-assistant.override {
      extraComponents = [
        "frontend"
        "esphome"
        "met"
        "mqtt"
        "spotify"
        "wled"
        "rmvtransport"
        "denonavr"
        "kodi"
      ];
    }).overrideAttrs (_: {
      doInstallCheck = false;
    });
    lovelaceConfig = {
      title = "Home";
      switch = [
        {
          platform = "flux";
          lights = [
            "light.living_room_lights"
            "light.hallway_lamp"
          ];
        }
      ];
      views = [
        {
          title = "Home";
          cards = [
            {
              title = "Living Room Floor Lamp";
              type = "light";
              entity = "light.living_room_floor_lamp";
            }
            {
              title = "Living Room Ceiling Lamp";
              type = "light";
              entity = "light.living_room_ceiling_lamp";
            }
            {
              title = "Living Room Dining Lamp";
              type = "light";
              entity = "light.living_room_dining_lamp";
            }
            {
              type = "light";
              entity = "light.living_room_lights";
            }
            {
              title = "Hallway Lamp";
              type = "light";
              entity = "light.hallway_lamp";
            }
            {
              title = "Weather";
              type = "weather-forecast";
              entity = "weather.home";
              show_forecast = true;
            }
            {
              title = "Bedroom Lamp";
              type = "light";
              entity = "light.bedroom_lights";
            }
            {
              name = "Ambient";
              type = "button";
              show_state = false;
              tap_action = {
                action = "call-service";
                service = "scene.turn_on";
                service_data = {
                  entity_id = "scene.ambient";
                };
              };
            }
            {
              name = "Sleep";
              type = "button";
              show_state = false;
              tap_action = {
                action = "call-service";
                service = "scene.turn_on";
                service_data = {
                  entity_id = "scene.sleep";
                };
              };
            }
            {
              name = "TV";
              type = "button";
              show_state = false;
              tap_action = {
                action = "call-service";
                service = "scene.turn_on";
                service_data = {
                  entity_id = "scene.tv";
                };
              };
            }
          ];
        }
        {
          title = "Transport";
          cards = [
            {
              title = "DA TZ Rhein-Main";
              type = "custom:rmv-card";
              entity = [
                "sensor.darmstadt_tz_rhein_main"
              ];
            }
            {
              title = "DA Hbf";
              type = "custom:rmv-card";
              entity = [
                "sensor.darmstadt_hauptbahnhof"
              ];
            }
          ];
        }
        {
          title = "Media";
          cards =
            [
              {
                type = "custom:mini-media-player";
                name = "Spotify";
                entity = "media_player.spotify_andir0815";
              }
              {
                type = "custom:mini-media-player";
                name = "Amplifier";
                entity = "media_player.denon";
              }
              {
                type = "custom:mini-media-player";
                name = "Kodi";
                entity = "media_player.crappy";
                hide = {
                  power = true;
                  source = true;
                };
              }
              {
                type = "vertical-stack";
                title = "Snapcast Devices";
                cards =
                  let
                    snapcast_devices = {
                      HDMI = "media_player.snapcast_client_hdmi";
                      "Workstation" = "media_player.snapcast_client_wrt";
                      "BT Speaker" = "media_player.snapcast_client_bt_speaker";
                    };
                  in
                  lib.mapAttrsToList
                    (name: entity: {
                      inherit name entity;
                      type = "custom:mini-media-player";
                      hide = {
                        power = true;
                      };
                    })
                    snapcast_devices;
              }
            ];
        }
        {
          title = "Tomatoes";
          cards =
            let
              mkMoisture = entity: name: {
                inherit name;
                entities = [ entity ];
                type = "custom:mini-graph-card";
                unit = "%";
                lower_bound = 0;
                upper_bound = 100;
                hour24 = true;
                icon = "mdi:waves-arrow-up";
              };

              mkPump = entity: name: {
                inherit entity name;
                type = "entity";
                icon = "mdi:water-pump";
                state_color = true;
              };
            in
            [
              {
                type = "custom:mini-graph-card";
                name = "Temperature Outside";
                entities = [ "sensor.0x00158d00056a19b8_temperature" ];
                hour24 = true;
              }
              {
                type = "custom:mini-graph-card";
                entities = [ "sensor.0x00158d00056a19b8_humidity" ];
                name = "Humidity Outside";
                hour24 = true;
              }
              {
                type = "gauge";
                entity = "sensor.0x00158d00056a19b8_battery";
                name = "Temperature/Humidity Sensor Battery";
                unit = "%";
                min = 0;
                max = 100;
                severity = {
                  red = 20;
                  yellow = 40;
                  green = 65;
                };
              }

              (mkMoisture "sensor.moisture_1" "Moisture 1")
              (mkMoisture "sensor.moisture_2" "Moisture 2")
              (mkMoisture "sensor.moisture_3" "Moisture 3")
              (mkMoisture "sensor.moisture_4" "Moisture 4")
              (mkPump "switch.pump_1" "Pump 1")
              (mkPump "switch.pump_2" "Pump 2")
              (mkPump "switch.pump_3" "Pump 3")
              (mkPump "switch.pump_4" "Pump 4")
            ];
        }
      ];
    };
    config = {
      default_config = { };

      zone = [
        {
          name = "Home";
          latitude = "!secret home_latitude";
          longitude = "!secret home_longitude";
          radius = 25;
          icon = "mdi:account-multiple";
        }
      ];

      scene = [
        {
          name = "Ambient";
          entities = {
            "light.living_room_ceiling_lamp" = {
              state = "off";
            };
            "light.living_room_floor_lamp" = {
              state = "on";
              brightness_pct = 15;
            };
            "light.hallway_lamp" = {
              state = "on";
              brightness_pct = 10;
            };
          };
        }
        {
          name = "Sleep";
          entities = {
            "light.living_room_lights".state = "off";
            "light.hallway_lamp".state = "off";
            "light.bedroom_lights".state = "off";
            "media_player.denon".state = "off";
          };
        }
        {
          name = "TV";
          entities = {
            "light.living_room_lights".state = "off";
            "light.hallway_lamp".state = "off";
            "media_player.denon" = {
              state = "playing";
              source = "GAME2";
            };
          };
        }
      ];

      group = {
        living_room_lights = {
          name = "Living Room Lights";
          entities = [
            "light.living_room_lights"
          ];
        };
        my_devices = {
          name = "My Devices";
          entities = [
            "device_tracker.pixel_4"
          ];
        };
      };

      light = [
        {
          platform = "group";
          name = "Living Room Floor Lamp";
          entities = [
            "light.0x7cb03eaa00aa8dcc"
            "light.0x84182600000e37c2"
            "light.0x7cb03eaa00aa87a8"
            "light.0x7cb03eaa00aa8924"
          ];
        }
        {
          platform = "group";
          name = "Living Room Ceiling Lamp";
          entities = [
            "light.0x001788010b9c608f"
            "light.0x001788010b9974a3"
            "light.0x001788010b9971a2"
          ];
        }
        {
          platform = "group";
          name = "Living Room Dining Lamp";
          entities = [
            "light.0x001788010b9996f7"
          ];
        }
        {
          platform = "group";
          name = "Living Room Lights";
          entities = [
            "light.living_room_floor_lamp"
            "light.living_room_ceiling_lamp"
            "light.living_room_dining_lamp"
          ];
        }
        {
          platform = "group";
          name = "Hallway lamp";
          entities = [
            "light.0x7cb03eaa00ae0d59"
          ];
        }
        {
          platform = "group";
          name = "Bedroom Lights";
          entities = [
            "light.0x7cb03eaa0a00bab7"
          ];
        }
      ];

      lovelace = {
        mode = "yaml";
        resources = lib.traceVal pkgs.lovelaceModules.allResources.resources;
      };
      homeassistant = {
        name = "Home";
        unit_system = "metric";
        currency = "EUR";
        auth_providers = [
          {
            type = "trusted_networks";
            allow_bypass_login = true;
            trusted_networks = [
              "fd21:a07e:735e::/48"
              "172.20.24.0/24"
            ];
          }
          {
            type = "homeassistant";
          }
        ];
      };
      http = {
        server_host = "::1";
        trusted_proxies = [ "::1" ];
        use_x_forwarded_for = true;
      };
      mqtt = {
        broker = "10.250.43.1";
        discovery = true;
      };
      automation = lib.mapAttrsToList (alias: value: { id = alias; inherit alias; } // value) {
        "Turn off the music" = {
          trigger = [
            {
              platform = "time";
              at = "03:00:00";
            }
          ];
          condition = [ ];
          action = [
            {
              service = "media_player.turn_off";
              target.entity_id = "media_player.denon";
            }
          ];
        };
        "Turn off the lights off when I leave the house" = {
          trigger = [
            {
              platform = "zone";
              event = "leave";
              zone = "zone.home";
              entity_id = "device_tracker.pixel_4";
            }
          ];
          condition = [ ];
          action = [
            {
              service = "light.turn_off";
              target.entity_id = "all";
            }
          ];
        };
        "Turn off the music when I leave the house" = {
          trigger = [
            {
              platform = "zone";
              event = "leave";
              zone = "zone.home";
              entity_id = "device_tracker.pixel_4";
            }
          ];
          condition = [ ];
          action = [
            {
              service = "media_player.turn_off";
              target.entity_id = "media_player.denon";
            }
          ];
        };
        "Turn the light on when it gets dark or when I get home while it is dark" =
          let
            # living room dining area
            light_sensor = "sensor.0x001788010b09f8b9_illuminance_lux";
          in
          {
            trigger = [
              {
                platform = "numeric_state";
                entity_id = light_sensor;
                below = 10;
              }
              {
                platform = "zone";
                event = "enter";
                zone = "zone.home";
                entity_id = "device_tracker.pixel_4";
              }
            ];
            condition = [
              {
                condition = "and";
                conditions = [
                  {
                    condition = "zone";
                    entity_id = "device_tracker.pixel_4";
                    zone = "zone.home";
                  }
                  {
                    # between 10:00 and 8pm
                    condition = "time";
                    after = "10:00:00";
                    before = "22:00:00";
                  }
                  {
                    condition = "numeric_state";
                    entity_id = light_sensor;
                    below = 10;
                  }
                ];
              }
            ];
            action = [
              {
                service = "scene.turn_on";
                target.entity_id = "scene.ambient";
              }
            ];
          };
      };

      spotify = {
        client_id = "!secret spotify_client_id";
        client_secret = "!secret spotify_client_secret";
      };

      device_sun_light_trigger = {
        light_group = "light.living_room_lights";
        #light_profile = "relax";
        device_group = "group.my_devices";
        disable_turn_off = false;
      };

      sensor = [
        {
          platform = "rmvtransport";
          next_departure = [
            {
              # TZ Rhein-Main
              station = "3024456";
              time_offset = 5;
              direction = "Darmstadt Luisenplatz";
            }
            {
              # TZ Rhein-Main
              station = "3024456";
              time_offset = 5;
              direction = "Darmstadt-Kranichstein Bordsdorffstrasse";
            }
          ];
        }
        {
          platform = "rmvtransport";
          next_departure = [
            {
              # DA Hbf
              station = "3004734";
              time_offset = 5;
              direction = "Darmstadt Luisenplatz";
            }
            {
              station = "3004734";
              time_offset = 5;
              direction = "Darmstadt-Kranichstein Bordsdorffstrasse";
            }
            {
              station = "3004734";
              time_offset = 5;
              direction = "Weinheim";
            }
          ];
        }
      ];
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."home.rammhold.de" = {
      default = true;
      locations."/nix-resources/".alias = (toString pkgs.lovelaceModules.allResources.wwwRoot) + "/";
      locations."/" = {
        proxyPass = "http://[::1]:8123";
        proxyWebsockets = true;
      };
      extraConfig = ''
        allow 127.0.0.0/8;
        allow ::1/128;
        allow 172.20.24.0/24;
        allow fd21:a07e:735e::/48;
        deny all;
      '';
    };
  };
  networking.firewall.allowedTCPPorts = [ 80 ];

}

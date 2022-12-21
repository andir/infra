{ lib, pkgs, ... }:
let
  mkSensor = id: features:
    (lib.genAttrs features (feat: "sensor.${id}_${feat}")) // { inherit id; };
  mkAqaraTempSensor = id: mkSensor id [ "temperature" "battery" "humidity" ];

  sensors = {
    motion_sensor_livingroom = mkSensor "0x001788010b09f8b9" [ "temperature" "battery" "occupancy" ];
    temperature_sensor_livingroom = mkAqaraTempSensor "0x00158d00057f9d18";
    motion_sensor_hallway = mkSensor "0x001788010b095fd9" [ "temperature" "battery" "occupancy" ];
    temperature_sensor_bathroom = mkAqaraTempSensor "0x00158d000588ceb6";
    temperature_sensor_bedroom = mkAqaraTempSensor "0x00158d000588cc10";
    temperature_sensor_kitchen = mkAqaraTempSensor "0x00158d00058a6475";
    temperature_sensor_balcony = mkAqaraTempSensor "0x00158d00056a19b8";
  };

  lights = lib.genAttrs [
    "living_room_floor_lamp"
    "living_room_ceiling_lamp"
    "living_room_dining_lamp"
    "living_room_work_desk_lamp"
  ]
    (l: "light.${l}");


  climateDevices = {
    livingRoom."0x943469fffe70bfc4" = {
      nominal_temperature = 20;
      dormant_temperature = 18;
    };
    bedRoom."0x70ac08fffe547ee7" = {
      nominal_temperature = 18;
      dormant_temperature = 18;
    };
    bathroom."0x70ac08fffe4dd8c9" = {
      nominal_temperature = 19;
      dormant_temperature = 18;
    };
    kitchen."0x70ac08fffe550abb" = {
      nominal_temperature = 15;
      dormant_temperature = 15;
    };
  };

  allClimateDevices = builtins.foldl' (acc: item: acc // item) { } (
    (builtins.attrValues climateDevices)
  );
in
{

  imports = [
    ./motion-aware-lights.nix
    (import ./dafoss-external-temperature.nix {
      rooms = {
        livingRoom = {
          climateDevices = climateDevices.livingRoom;
          temperatureSensors = [
            sensors.temperature_sensor_livingroom.temperature
          ];
        };
        bedRoom = {
          climateDevices = climateDevices.bedRoom;
          temperatureSensors = [
            sensors.temperature_sensor_bedroom.temperature
          ];
        };
        bathroom = {
          climateDevices = climateDevices.bathroom;
          temperatureSensors = [
            sensors.temperature_sensor_bathroom.temperature
          ];
        };
        kitchen = {
          climateDevices = climateDevices.kitchen;
          temperatureSensors = [
            sensors.temperature_sensor_kitchen.temperature
          ];
        };
      };
    })
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
        "xiaomi_miio"
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
          cards =
            let
              verticalStack = data: { type = "vertical-stack"; } // data;
              horizontalStack = data: { type = "horizontal-stack"; } // data;
              miniGraph = data: { type = "custom:mini-graph-card"; } // data;
              miniTemperatureGraph = entities: miniGraph ({
                name = "Temperature";
                icon = "mdi:thermometer";
                hours_to_show = "8";
                points_per_hour = "3";
                inherit entities;
              });
              miniHumidityGraph = entities: miniGraph ({
                name = "Humidity";
                icon = "mdi:cloud-percent-outline";
                hours_to_show = "8";
                points_per_hour = "3";
                inherit entities;
              });
              miniBatteryGraph = entities: miniGraph ({
                name = "Battery";
                icon = "mid:battery-high";
                hours_to_show = "24";
                points_per_hour = "1";
                inherit entities;
              });

              o = cond: content: if cond then [ content ] else [ ];

              mkLight = title: entity: { inherit title entity; type = "light"; };

              mkMultipleEntityRow = { entity, entities ? [ ], ... }@args: {
                type = "custom:multiple-entity-row";
                inherit entity entities;
              } // args;

              mkRoom =
                { name
                , temperature ? [ ]
                , humidity ? [ ]
                , battery ? [ ]
                , cards ? [ ]
                , heating ? { }
                }:
                let
                  temperatureEntities = temperature
                    ++ (map (id: "sensor.${id}_temperature") heating);
                in
                verticalStack {
                  cards = [
                    (horizontalStack {
                      title = name;
                      cards = [
                        (miniTemperatureGraph temperature)
                        (miniHumidityGraph humidity)
                      ];
                    })
                  ]
                  ++ (map
                    (id:
                      mkMultipleEntityRow {
                        title = "Thermostat";
                        entity = "climate.${id}";
                        show_state = false;
                        entities = [
                          { entity = "sensor.${id}_temperature"; name = "Target"; /* icon = "mdi:home-thermometer"; */ }
                          { entity = "sensor.${id}_battery"; name = "battery"; /* icon = "mdi:battery"; */ }
                          { entity = "sensor.${id}_pi_heating_demand"; name = "Load %"; /* icon = "mdi:radiator"; */ }
                        ];
                      })
                    (builtins.attrNames heating))
                  ++ cards;
                };


            in
            [
              (mkRoom {
                name = "Livingroom";
                temperature = [
                  sensors.temperature_sensor_livingroom.temperature
                  sensors.motion_sensor_livingroom.temperature
                ];
                humidity = [
                  sensors.temperature_sensor_livingroom.humidity
                ];
                battery = [
                  sensors.temperature_sensor_livingroom.battery
                  sensors.motion_sensor_livingroom.battery
                ];

                heating = climateDevices.livingRoom;

                cards = [
                  {
                    type = "custom:multiple-entity-row";
                    entity = "light.living_room_lights";
                    icon = "mdi:lightbulb-outline";
                    toggle = true;
                    entities = [
                      { tap_action.action = "toggle"; name = "Stehlampe"; entity = lights.living_room_floor_lamp; icon = "mdi:floor-lamp"; }
                      { tap_action.action = "toggle"; name = "Esstisch"; entity = lights.living_room_dining_lamp; icon = "mdi:ceiling-light-outline"; }
                      { tap_action.action = "toggle"; name = "Deckenlampe"; entity = lights.living_room_ceiling_lamp; icon = "mdi:chandelier"; }
                      { tap_action.action = "toggle"; name = "Schreibtisch"; entity = lights.living_room_work_desk_lamp; icon = "mdi:lamps"; }
                    ];
                  }
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
                    #type = "custom:mini-media-player";
                    type = "media-control";
                    name = "Kodi";
                    entity = "media_player.crappy";
                    #hide = {
                    #  power = true;
                    #  source = true;
                    #};
                  }
                ];
              })
              (mkRoom {
                name = "Bedroom";
                temperature = [ sensors.temperature_sensor_bedroom.temperature ];
                humidity = [ sensors.temperature_sensor_bedroom.humidity ];
                battery = [ sensors.temperature_sensor_bedroom.battery ];
                heating = climateDevices.bedRoom;
              })
              (mkRoom {
                name = "Kitchen";
                temperature = [ sensors.temperature_sensor_kitchen.temperature ];
                humidity = [ sensors.temperature_sensor_kitchen.humidity ];
                battery = [ sensors.temperature_sensor_kitchen.battery ];
                heating = climateDevices.kitchen;
              })
              (mkRoom {
                name = "Bathroom";
                temperature = [ sensors.temperature_sensor_bathroom.temperature ];
                humidity = [ sensors.temperature_sensor_bathroom.humidity ];
                battery = [ sensors.temperature_sensor_bathroom.battery ];
                heating = climateDevices.bathroom;
              })
              (mkRoom {
                name = "Hallway";
                temperature = [ sensors.motion_sensor_hallway.temperature ];
                humidity = [ ];
                battery = [ sensors.motion_sensor_hallway.battery ];
              })
              (verticalStack {
                title = "Balcony";
                cards = [
                  (mkMultipleEntityRow {
                    entity = sensors.temperature_sensor_balcony.temperature;
                  })
                ];
              })
              (verticalStack {
                title = "Vacuum";
                cards = [
                  {
                    type = "custom:vacuum-card";
                    entity = "vacuum.roborock_s7_maxv";
                    actions = { };
                    stats = {
                      default = [
                        { attribute = "filter_left"; unit = "hours"; subtitle = "Filter"; }
                        { attribute = "side_brush_left"; unit = "hours"; subtitle = "Side brush"; }
                        { attribute = "main_brush_left"; unit = "hours"; subtitle = "Main brush"; }
                        { attribute = "sensor_dirty_left"; unit = "hours"; subtitle = "Sensors"; }
                      ];
                      cleaning = [
                        { attribute = "cleaning_time"; unit = "minutes"; subtitle = "Cleaning time"; }
                      ];
                    };
                    shortcuts = [
                      {
                        name = "Clean living room";
                        service = "script.vacuum_livingroom";
                        icon = "mdi:sofa";
                      }
                      {
                        name = "Clean bedroom";
                        service = "script.vacuum_bedroom";
                        icon = "mdi:bed-empty";
                      }
                      {
                        name = "Clean kitchen";
                        service = "script.vacuum_kitchen";
                        icon = "mdi:silverware-fork-knife";
                      }
                    ];
                  }
                ];
              })
            ];
        }
        {
          title = "Old";
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
              title = "Work Desk Lamp";
              type = "light";
              entity = "light.living_room_work_desk_lamp";
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
              title = "Charge Dyson";
              type = "button";
              entity = "switch.dyson_charging_switch";
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
            {
              name = "Spotify";
              type = "button";
              show_state = false;
              tap_action = {
                action = "call-service";
                service = "scene.spotify";
                service_data = {
                  entity_id = "scene.spotify";
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
          title = "Vacuum";
          cards = [
            {
              type = "entities";
              entities = [
                {
                  entity = "sensor.roborock_s7_maxv_current_clean_area";
                  name = "Current clean area";
                }
                {
                  entity = "sensor.roborock_s7_maxv_current_clean_duration";
                  name = "Current clean duration";
                }
                {
                  entity = "sensor.roborock_s7_maxv_filter_left";
                  name = "Filter left";
                }
                {
                  entity = "sensor.roborock_s7_maxv_last_clean_area";
                  name = "Last clean area";
                }
                {
                  entity = "sensor.roborock_s7_maxv_last_clean_duration";
                  name = "Last clean duration";
                }
                {
                  entity = "sensor.roborock_s7_maxv_last_clean_end";
                  name = "Last clean end";
                }
                {
                  entity = "sensor.roborock_s7_maxv_last_clean_start";
                  name = "Last clean start";
                }
                {
                  entity = "sensor.roborock_s7_maxv_main_brush_left";
                  name = "Main brush left";
                }
                {
                  entity = "binary_sensor.roborock_s7_maxv_mop_attached";
                  name = "Mop attached";
                }
                {
                  entity = "sensor.roborock_s7_maxv_sensor_dirty_left";
                  name = "Sensor dirty left";
                }
                {
                  entity = "sensor.roborock_s7_maxv_side_brush_left";
                  name = "Side brush left";
                }
                {
                  entity = "binary_sensor.roborock_s7_maxv_water_box_attached";
                  name = "Water box attached";
                }
                {
                  entity = "binary_sensor.roborock_s7_maxv_water_shortage";
                  name = "Water shortage";
                }
              ];
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
        {
          title = "Batteries";
          cards = [
            {
              type = "custom:auto-entities";
              card = {
                type = "custom:battery-state-card";
                title = "All Batteries";
              };
              filter.include = [
                { entity_id = "sensor.*.battery"; }
              ];
            }
          ];
        }

      ];
    };
    config = {
      default_config = { };

      template = map
        (climateDevice:
          {
            sensor = [
              {
                name = "${climateDevice} temperature";
                state = "{{ state_attr('climate.${climateDevice}', 'temperature') }}";
                state_class = "measurement";
                unit_of_measurement = "°C";
              }
            ];
          }
        )
        (builtins.attrNames allClimateDevices);

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
        {
          name = "Spotify";
          entities = {
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
            "device_tracker.iphone"
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
          name = "Living Room Work Desk Lamp";
          entities = [
            "light.0x7cb03eaa0a00a84b"
          ];
        }
        {
          platform = "group";
          name = "Living Room Lights";
          entities = [
            "light.living_room_floor_lamp"
            "light.living_room_ceiling_lamp"
            "light.living_room_dining_lamp"
            "light.living_room_work_desk_lamp"
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
              entity_id = "device_tracker.iphone";
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
        "Lower the heating when I leave the house" = {
          trigger = [
            {
              platform = "zone";
              event = "leave";
              zone = "zone.home";
              entity_id = "device_tracker.iphone";
            }
          ];
          condition = [ ];
          action = map
            (id: {
              service = "climate.set_temperature";
              target.entity_id = "climate.${id}";
              data = {
                temperature = allClimateDevices.${id}.dormant_temperature;
                hvac_mode = "heat";
              };
            })
            (builtins.attrNames allClimateDevices);
        };
        "Turn off the music when I leave the house" = {
          trigger = [
            {
              platform = "zone";
              event = "leave";
              zone = "zone.home";
              entity_id = "device_tracker.iphone";
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
        "Work Desk Switch Living room lights ON" = {
          trigger = [
            {
              platform = "state";
              entity_id = "switch.0x50325ffffe739d21";
              to = "on";
              from = "off";
            }
          ];
          action = [
            {
              service = "light.turn_on";
              target.entity_id = "light.living_room_lights";
            }
          ];
        };
        "Work Desk Switch Living room lights OFF" = {
          trigger = [
            {
              platform = "state";
              entity_id = "switch.0x50325ffffe739d21";
              to = "off";
              from = "on";
            }
          ];
          action = [
            {
              service = "light.turn_off";
              target.entity_id = "light.living_room_lights";
            }
          ];
        };
      };

      # spotify = {
      #   client_id = "!secret spotify_client_id";
      #   client_secret = "!secret spotify_client_secret";
      # };

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
    virtualHosts."z2m.rammhold.de" = {
      locations."/" = {
        proxyPass = "http://[::1]:8083";
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

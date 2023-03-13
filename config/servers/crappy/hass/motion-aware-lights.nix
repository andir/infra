{ lib, ... }:
let
  mkNightMotionLight =
    { name
    , occupancy_sensor
    , illuminance_sensor
    , light
    , timer_name
    , cooloff ? "00:00:30"
    , elevation_level ? 4
    , sun_entity ? "sun.sun"
    , brightness_pct ? 45
    , transition ? 2
    }:
    let
      script_name = "${name}_activate";
    in
    {
      config = {
        script = {
          ${script_name}.sequence = [
            {
              service = "light.turn_on";
              target.entity_id = [
                light
              ];
              data = {
                inherit brightness_pct transition;
              };
            }
            {
              service = "timer.start";
              target.entity_id = "timer.${timer_name}";
            }
          ];
        };
        automation = lib.mapAttrsToList (alias: value: { id = alias; inherit alias; } // value) {
          ${name} = {
            trigger = [
              {
                platform = "state";
                entity_id = occupancy_sensor;
                to = "on";
              }
            ];
            condition = [
              {
                condition = "and";
                conditions = [
                  {
                    condition = "or";
                    conditions = [
                      {
                        condition = "numeric_state";
                        entity_id = sun_entity;
                        attribute = "elevation";
                        below = elevation_level;
                      }
                      {
                        condition = "numeric_state";
                        entity_id = illuminance_sensor;
                        below = 10;
                      }
                    ];
                  }

                  # ensure that the light wasn't switched on manually, in that case it has to be turned off manually again
                  {
                    condition = "state";
                    entity_id = light;
                    state = "off";
                  }
                ];
              }
            ];
            action = [{ service = "script.${script_name}"; }];
          };

          "${name}_timer_expiry_when_no_movement" = {
            trigger = [
              {
                platform = "event";
                event_type = "timer.finished";
                event_data.entity_id = "timer.${timer_name}";
              }
            ];
            condition = [
              {
                condition = "state";
                entity_id = occupancy_sensor;
                state = "off";
              }
            ];

            action = [{ service = "light.turn_off"; target.entity_id = [ light ]; }];
          };

          "${name}_timer_expiry_when_movement" = {
            trigger = [
              {
                platform = "event";
                event_type = "timer.finished";
                event_data.entity_id = "timer.${timer_name}";
              }
            ];

            condition = [
              {
                condition = "state";
                entity_id = occupancy_sensor;
                state = "on";
              }
            ];

            action = [{ service = "script.${script_name}"; }];
          };
          "${name}_timer_stop_when_manual_change" = {
            trigger = [
              {
                platform = "state";
                entity_id = light;
                to = "";
              }
              {
                platform = "numeric_state";
                entity_id = light;
                to = "";
              }
            ];
            condition = [
              {
                condition = "state";
                entity_id = "timer.${timer_name}";
                state = "active";
              }
            ];
            action = [
              {
                service = "timer.stop";
                target.entity_id = "timer.${timer_name}";
              }
            ];
          };
        };

        timer.${timer_name} = {
          duration = cooloff;
        };
      };
    };
in
lib.mkMerge [
  {
    services.home-assistant = mkNightMotionLight rec {
      name = "dining_table_motion_sensor_when_dark";

      occupancy_sensor = "binary_sensor.0x001788010b09f8b9_occupancy";
      illuminance_sensor = "sensor.0x001788010b09f8b9_illuminance_lux";
      light = "light.living_room_dining_lamp";

      timer_name = "${name}_timer";
      cooloff = "00:00:25";

      elevation_level = 4;
    };
  }
  {
    services.home-assistant = mkNightMotionLight rec {
      name = "hallway_motion_sensor_when_dark";

      occupancy_sensor = "binary_sensor.0x001788010b095fd9_occupancy";
      illuminance_sensor = "sensor.0x001788010b095fd9_illuminance_lux";
      light = "light.hallway_lamp";

      timer_name = "${name}_timer";
      cooloff = "00:00:25";

      elevation_level = 4;
    };
  }
]

{ rooms }:
{ config, lib, ... }:
let
  mkAutomation = name: { climateDevices ? { }, temperatureSensors ? [ ] }:
    let
      sync_script_name = lib.toLower "synchronize_room_temperature_to_danfoss_in_${name}";
      automation_name = sync_script_name;
      timer_id = "${automation_name}_timer";
    in
    if climateDevices == { } || temperatureSensors == [ ] then { } else {
      config = {
        script.${sync_script_name}.sequence = [
          {
            variables = {
              temperatures = map (sensor: "{{ states('${sensor}')|float*100|round(0) }}") temperatureSensors;
            };
          }
          {
            variables = {
              mean_temperature = "{{ temperatures|average }}";
            };
          }
        ] ++
        (map
          (climateDeviceName: {
            service = "number.set_value";
            target.entity_id = "number.${climateDeviceName}_external_measured_room_sensor";
            data.value = "{{ mean_temperature|float }}";
          })
          (builtins.attrNames climateDevices));

        timer = lib.mapAttrs'
          (climateDevice: _: lib.nameValuePair "${timer_id}_${climateDevice}" {
            duration = "300";
          })
          climateDevices;

        automation =
          lib.mapAttrsToList (alias: value: { id = alias; inherit alias; } // value)
            (lib.mapAttrs'
              (climateDevice: _: lib.nameValuePair "${automation_name}_${climateDevice}" {
                # on temperature change of any of the sensors
                trigger = map
                  (sensor: {
                    platform = "state";
                    entity_id = sensor;
                  })
                  temperatureSensors
                # or every 30 minutes
                ++ [{
                  platform = "event";
                  event_type = "timer.finished";
                  event_data.entity_id = "${timer_id}_${climateDevice}";
                }];
                variables = {
                  radiator_covered_status = "{{ states('switch.${climateDevice}_radiator_covered') }}";
                  min_update_minutes = "{% if radiator_covered_status == 'off' %}30{% else %}5{% endif %}";
                  max_update_minutes = "{% if radiator_covered_status == 'off' %}180{% else %}30{% endif %}";
                };
                condition = [
                  {
                    condition = "template";
                    value_template = "{{ as_timestamp(now()) - as_timestamp(state_attr(this.entity_id, 'last_triggered'),0) > 60 * min_update_minutes }}";
                  }
                ];
                action = [
                  { service = "script.${sync_script_name}"; }
                  { service = "timer.start"; target.entity_id = "timer.${timer_id}_${climateDevice}"; data.duration = "{{ max_update_minutes * 60 }}"; }
                ];
                mode = "single";
              })
              climateDevices);
      };
    };
in
lib.mkMerge (map
  (room:
  { services.home-assistant = mkAutomation room rooms.${room}; })
  (builtins.attrNames rooms))

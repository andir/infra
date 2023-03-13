{ combinations }:
{ config, lib, ... }:
let
  mkConfig = name: { switch, light, increment ? 25.5, decrement ? 25.5, delay ? 100 }: {
    automation = lib.mapAttrsToList (alias: value: { id = alias; inherit alias; } // value) {
      "${name} turn on on button press" = {
        trigger = [ switch.on ];
        action = [
          { service = "light.turn_on"; target.entity_id = [ light ]; }
        ];
      };
      "${name} turn off on button press" = {
        trigger = [ switch.off ];
        action = [
          { service = "light.turn_off"; target.entity_id = [ light ]; }
        ];
      };
      "${name} turn the brightness up (while held)" = {
        mode = "restart";
        trigger = [
          (switch.brightness_move_up // { id = "up"; })
          (switch.brightness_stop // { id = "stop"; })
        ];
        action = [
          {
            choose = [
              {
                conditions = [ "{{ trigger.id == 'stop' }}" ];
                sequence = [ ];
              }
              {
                conditions = [ "{{ trigger.id == 'up' }}" ];
                sequence = [
                  {
                    repeat = {
                      while = "{{ true }}";
                      sequence = [
                        # debounce
                        { delay.milliseconds = delay; }

                        {
                          service = "light.turn_on";
                          target.entity_id = [ light ];
                          data.brightness_step = increment;
                        }
                      ];
                    };
                  }
                ];
              }
            ];
          }
        ];
      };
      "${name} turn the brightness down (while held)" = {
        mode = "restart";
        trigger = [
          (switch.brightness_move_down // { id = "down"; })
          (switch.brightness_stop // { id = "stop"; })
        ];
        action = [
          {
            choose = [
              {
                conditions = [ "{{ trigger.id == 'stop' }}" ];
                sequence = [ ];
              }
              {
                conditions = [ "{{ trigger.id == 'down' }}" ];
                sequence = [
                  {
                    repeat = {
                      while = "{{ true }}";
                      sequence = [
                        # debounce
                        { delay.milliseconds = delay; }

                        # decrease by 15/255
                        {
                          service = "light.turn_on";
                          target.entity_id = [ light ];
                          data.brightness_step = decrement;
                        }
                      ];
                    };
                  }
                ];
              }
            ];
          }
        ];
      };
    };
  };

in
{
  services.home-assistant.config = lib.mkMerge (lib.attrValues (lib.mapAttrs mkConfig combinations));
}

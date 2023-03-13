{ lib, ... }:
let
  minutes = 45;
  limit = 850;
in
{
  services.home-assistant.config.automation = [
    {
      id = "power-consumption-usage-alert";
      alias = "power-consumption-usage-alert";

      trigger = {
        platform = "numeric_state";
        entity_id = "sensor.power_consumption";
        above = limit;
        for.minutes = minutes;
      };

      action = [
        {
          service = "notify.notify";
          data = {
            title = "Power usage is high";
            message = "Power usage is above ${toString limit} Watt for ${toString minutes} minutes.";
          };
        }
      ];
    }
  ];
}

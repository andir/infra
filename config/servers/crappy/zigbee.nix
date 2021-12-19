{ pkgs, ... }:
{
  # for updating the conbee II firmware via the deconz image:
  # mkdir /tmp/test
  # docker run  --rm --privileged  -v /tmp/test:/root/.local/share/dresden-elektronik/deCONZ --device=/dev/ttyACM0 --entrypoint /firmware-update.sh -it marthoc/deconz
  virtualisation.docker.enable = true;

  services.zigbee2mqtt = {
    enable = true;
    package = pkgs.my-zigbee2mqtt;
    settings = {
      permit_join = false;
      serial = {
        port = "/dev/serial/by-id/usb-dresden_elektronik_ingenieurtechnik_GmbH_ConBee_II_DE2409365-if00";
        adapter = "deconz";
      };
      mqtt = {
        server = "mqtt://10.250.43.1";
        keepalive = 60;
      };

      advanced = {
        log_output = [ "console" ];
        log_level = "debug";

        cache_state = true;
        cache_state_persistent = true;
        cache_state_send_on_startup = true;
        last_seen = "epoch";

        homeassistant_discovery_topic = "homeassistant";
        homeassistant_status_topic = "homeassistant/status";
        homeassistant_legacy_entity_attributes = false;
        homeassistant_legacy_triggers = false;
      };

      devices = {
        "0x00158d000588cc10".friendly_name = "0x00158d000588cc10";
        "0x00158d00057f9d18".friendly_name = "0x00158d00057f9d18";
        "0x00158d00056a19b8".friendly_name = "0x00158d00056a19b8";
        "0x04cf8cdf3c8240ce".friendly_name = "0x04cf8cdf3c8240ce";
        "0x00158d00058a6475".friendly_name = "0x00158d00058a6475";
        "0x00158d000588ceb6".friendly_name = "0x00158d000588ceb6";

        "0x001788010b9c608f".friendly_name = "Living Room Ceiling 1";
        "0x001788010b9974a3".friendly_name = "Living Room Ceiling 2";
        "0x001788010b9971a2".friendly_name = "Living Room Ceiling 3";

        "0x001788010b9996f7".friendly_name = "Living Room Dining Lamp";

        "0x7cb03eaa00aa8dcc".friendly_name = "Living Room Floor Lamp 2";
        "0x84182600000e37c2".friendly_name = "Living Room Floor Lamp 4";
        "0x7cb03eaa00aa87a8".friendly_name = "Living Room Floor Lamp 5";
        "0x7cb03eaa00aa8924".friendly_name = "Living Room Floor Lamp 6";

        "0x001788010b09f8b9".friendly_name = "Living Room Dining Motion";

        "0x7cb03eaa00ae0d59".friendly_name = "Hallway Lamp";
      };

      frontend = {
        port = 8083;
        host = "::1";
      };
    };
  };
}

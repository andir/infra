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
      };

      devices = {
        "0x00158d000588cc10".friendly_name = "0x00158d000588cc10";
        "0x00158d00057f9d18".friendly_name = "0x00158d00057f9d18";
        "0x00158d00056a19b8".friendly_name = "0x00158d00056a19b8";
        "0x04cf8cdf3c8240ce".friendly_name = "0x04cf8cdf3c8240ce";
        "0x00158d00058a6475".friendly_name = "0x00158d00058a6475";
        "0x00158d000588ceb6".friendly_name = "0x00158d000588ceb6";
      };

      frontend = {
        port = 8083;
        host = "::1";
      };
    };
  };
}

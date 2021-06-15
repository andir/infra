{ pkgs, ... }:
let
  simpleMqttExporter = pkgs.writers.writePython3 "simple-mqtt-exporter"
    {
      libraries = [ pkgs.python3Packages.paho-mqtt ];
    }
    (builtins.readFile ./mqtt2prom.py);
in
{
  services.mosquitto = {
    enable = true;
    users = { };
    aclExtraConf = ''
      topic readwrite #
    '';
    allowAnonymous = true;
    host = "10.250.43.1";
  };

  systemd.services.mqtt2prom = {
    after = [ "network.target" "mosquitto.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      DynamicUser = true;
      ExecStart = simpleMqttExporter;
      RuntimeDirectory = "mqtt2prom";
      Restart = "always";
      StandardOutput = "journal";
      StandardError = "journal";
      WorkingDirectory = "/run/mqtt2prom";
    };
  };

  services.prometheus.exporters.node.extraFlags = [ "--collector.textfile.directory /run/mqtt2prom" ];

  environment.systemPackages = [ pkgs.mosquitto ];
}

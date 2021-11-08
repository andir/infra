{ pkgs, ... }:
let
  simpleMqttExporter = pkgs.writers.writePython3 "simple-mqtt-exporter"
    {
      libraries = [ pkgs.python3Packages.paho-mqtt ];
      flakeIgnore = [ "E501" ];
    }
    (builtins.readFile ./mqtt2prom.py);
in
{
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        settings.allow_anonymous = true;
        acl = [
          "topic readwrite #"
        ];
        address = "10.250.43.1";
      }
    ];
  };

  systemd.services.mqtt2prom = {
    after = [ "network.target" "mosquitto.service" ];
    wantedBy = [ "multi-user.target" ];
    script = "exec ${simpleMqttExporter} $RUNTIME_DIRECTORY/output.prom $STATE_DIRECTORY/state.json";
    serviceConfig = {
      DynamicUser = true;
      RuntimeDirectory = "mqtt2prom";
      Restart = "always";
      StandardOutput = "journal";
      StandardError = "journal";
      WorkingDirectory = "/run/mqtt2prom";
      StateDirectory = "mqtt2prom";
    };
  };

  services.prometheus.exporters.node.extraFlags = [ "--collector.textfile.directory /run/mqtt2prom" ];

  environment.systemPackages = [ pkgs.mosquitto ];
}

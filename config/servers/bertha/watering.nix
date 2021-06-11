{ pkgs, ... }:
let
  simpleMqttExporter = pkgs.writers.writePython3 "simple-mqtt-exporter"
    {
      libraries = [ pkgs.python3Packages.paho-mqtt ];
    } ''
    # no fmt
    import paho.mqtt.client as mqtt
    import time
    import threading

    states = {}

    MAX_AGE_SECONDS = 30


    def cleanup_states():
        global states

        while True:
            time.sleep(MAX_AGE_SECONDS * 2)
            now = int(time.time() * 1000)
            to_delete = []
            for key, (_, ts) in states.items():
                if now - ts > MAX_AGE_SECONDS * 1000:
                    to_delete.append(key)

            for key in to_delete:
                print(f"deleting {key} from state")
                del states[key]


    threading.Thread(target=cleanup_states).start()


    def on_connect(client, userdata, flags, rc):
        print("connected")
        client.subscribe('experimental/watering/v0/sensor/+/state')


    def on_message(client, userdata, msg):
        now = int(time.time() * 1000)
        print(msg.topic, str(msg.payload))
        global states

        parts = msg.topic.split('/')
        _, _, _, _, sensor, _ = parts
        prefix = "watering_experiment_moisture_percent"
        metric_name = "%s{sensor=\"%s\"}" % (prefix, sensor)

        states[metric_name] = (msg.payload.decode(), now)

        with open("output.prom", "w") as fh:
            fh.write(f"# TYPE {prefix} gauge\n")
            for key, (value, ts) in states.items():
                fh.write(f"{key} {value}\n")


    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message

    client.connect("10.250.43.1", 1883, 60)

    client.loop_forever()
  '';
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

  systemd.services.watering_exporter = {
    after = [ "network.target" "mosquitto.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      DynamicUser = true;
      ExecStart = simpleMqttExporter;
      RuntimeDirectory = "watering_exporter";
      Restart = "always";
      StandardOutput = "journal";
      StandardError = "journal";
      WorkingDirectory = "/run/watering_exporter";
    };
  };

  services.prometheus.exporters.node.extraFlags = [ "--collector.textfile.directory /run/watering_exporter" ];

  environment.systemPackages = [ pkgs.mosquitto ];
}

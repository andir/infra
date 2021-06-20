import paho.mqtt.client as mqtt
import time
import threading
import json

states = {}

MAX_AGE_SECONDS = 30
# 3h should be enough for zigbee to report *any* change
ZIGBEE_MAX_AGE_SECONDS = 3600 * 3


def cleanup_states():
    global states

    while True:
        time.sleep(MAX_AGE_SECONDS * 2)
        now = int(time.time() * 1000)
        to_delete = []
        for key, (_, ts) in states.items():
            if key.startswith('watering_'):
                if now - ts > MAX_AGE_SECONDS * 1000:
                    to_delete.append(key)
            elif key.startswith('zigbee'):
                if now - ts > ZIGBEE_MAX_AGE_SECONDS * 1000:
                    to_delete.append(key)

        for key in to_delete:
            print(f"deleting {key} from state")
            del states[key]


threading.Thread(target=cleanup_states).start()


def on_connect(client, userdata, flags, rc):
    print("connected")
    client.subscribe('experimental/watering/v0/sensor/+/state')
    client.subscribe('experimental/watering/v1/sensor/+/state')
    client.subscribe('zigbee2mqtt/+')


def on_message(client, userdata, msg):
    now = int(time.time() * 1000)
    print(msg.topic, str(msg.payload))
    global states

    if msg.topic.startswith('experimental/watering/v0/sensor'):
        parts = msg.topic.split('/')
        _, _, _, _, sensor, _ = parts
        prefix = "watering_experiment_moisture_percent"
        metric_name = "%s{sensor=\"%s\"}" % (prefix, sensor)
        states[metric_name] = (msg.payload.decode(), now)
    elif msg.topic.startswith('experimental/watering/v1/sensor'):
        parts = msg.topic.split('/')
        _, _, _, _, sensor, _ = parts
        prefix = "watering_experiment_v1_moisture_percent"
        metric_name = "%s{sensor=\"%s\"}" % (prefix, sensor)
        states[metric_name] = (msg.payload.decode(), now)
    elif msg.topic.startswith('zigbee2mqtt/'):
        _, device = msg.topic.split('/', 1)
        payload = json.loads(msg.payload)
        for key, value in payload.items():
            metric_name = f'zigbee{{device="{device}", metric="{key}"}}'
            if value == 'ON':
                value = 1.0
            elif value == 'OFF':
                value = 0.0
            states[metric_name] = (value, now)

    with open("output.prom", "w") as fh:
        for key, (value, ts) in states.items():
            fh.write(f"{key} {value}\n")


client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

client.connect("10.250.43.1", 1883, 60)

client.loop_forever()

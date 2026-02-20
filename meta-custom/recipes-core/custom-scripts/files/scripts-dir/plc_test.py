import json
from time import sleep
import requests
import paho.mqtt.client as mqtt

TOPIC = "pub"
TOPIC_SUB = "sub"
# Hier werden die aktuellen Werte gesammelt
current_data = {}

# ==== MQTT CALLBACK ====
def on_message(client, userdata, message):
    global current_data
    payload = message.payload.decode()
    try:
        data = json.loads(payload)
        reported = data.get("state", {}).get("reported", {})
        print("Nachricht:", payload)
    except Exception as e:
        print("Ungültige Nachricht:", payload)
        print("Fehler:", e)

# ==== MQTT SETUP ====
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, "RPI_CM5")
client.on_message = on_message
client.connect("192.168.0.50", 1883 ) # تأكد من تعريف BROKER و PORT في هذا الملف أو في .env
client.subscribe(TOPIC)
client.loop_start()

print("Empfange MQTT-Daten... (Strg+C zum Beenden)")

# ==== HAUPTSCHLEIFE ====
try:
    toggle = 0
    while True:
        payload = {"state": {"M21":{"value" :[1]}}}
        client.publish(TOPIC_SUB, json.dumps(payload))
        sleep(1)
        
        payload = {"state": {"M22":{"value" :[0]}}}
        client.publish(TOPIC_SUB, json.dumps(payload))
        sleep(1)
        
        payload = {"state": {"M22":{"value" :[1]}}}
        client.publish(TOPIC_SUB, json.dumps(payload))
        sleep(1)
        
        payload = {"state": {"M21":{"value" :[0]}}}
        client.publish(TOPIC_SUB, json.dumps(payload))
        sleep(1)
        
        payload = {"state": {"M22":{"value" :[1]}}}
        client.publish(TOPIC_SUB, json.dumps(payload))
        sleep(1)
        
        payload = {"state": {"M21":{"value" :[0]}}}
        client.publish(TOPIC_SUB, json.dumps(payload))
        sleep(1)
        #print("Sent:", payload)

except KeyboardInterrupt:
    pass
finally:
    client.loop_stop()
    client.disconnect()

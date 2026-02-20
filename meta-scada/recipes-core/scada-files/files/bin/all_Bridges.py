import os
import json
import time
from dotenv import load_dotenv
import paho.mqtt.client as mqtt

# 1. Laden der Zugangsdaten
load_dotenv()

HIVEMQ_BROKER = os.getenv('MQTT_BROKER')
HIVEMQ_USER = os.getenv('MQTT_USER')
HIVEMQ_PASS = os.getenv('MQTT_PASS')

# PLC Einstellungen (Lokal)
PLC_IP = "192.168.0.50"
PLC_PORT = 1883
PLC_TOPIC_WRITE = "sub"  # Hierhin senden wir Befehle
PLC_TOPIC_READ = "pub"   # Von hier lesen wir Status

# Globaler Speicher für Inputs (I1-I8), damit wir immer das volle Array senden können
current_inputs = [0] * 8 

# ==============================================================================
# CLOUD CLIENT (HiveMQ) - Verbindung zur Website
# ==============================================================================

def on_cloud_connect(client, userdata, flags, rc, props=None):
    if rc == 0:
        print("[CLOUD] Verbunden mit HiveMQ!")
        client.subscribe("plc/control") # Höre auf Befehle von der Website
    else:
        print(f"[CLOUD] Fehler beim Verbinden: {rc}")

def on_cloud_message(client, userdata, msg):
    """
    Website sendet: {"output": "M20", "value": "ON"}
    Wir wandeln es um für PLC: {"state": {"M20": {"value": [1]}}}
    """
    try:
        payload = json.loads(msg.payload.decode())
        print(f"[CLOUD] Befehl empfangen: {payload}")

        output_name = payload.get("output") # z.B. "M20"
        command = payload.get("value")      # z.B. "ON"

        # Umwandlung: ON -> 1, OFF -> 0
        val_int = 1 if command == "ON" else 0

        # JSON für PLC bauen
        plc_payload = {
            "state": {
                output_name: {
                    "value": [val_int]
                }
            }
        }

        # An PLC senden
        client_plc.publish(PLC_TOPIC_WRITE, json.dumps(plc_payload))
        print(f"[TO PLC] Sende an {output_name}: {val_int}")

    except Exception as e:
        print(f"[CLOUD] Fehler beim Verarbeiten: {e}")

# ==============================================================================
# PLC CLIENT (Lokal) - Verbindung zur Siemens LOGO!
# ==============================================================================

def on_plc_connect(client, userdata, flags, rc, props=None):
    if rc == 0:
        print("[PLC] Verbunden mit lokaler PLC!")
        client.subscribe(PLC_TOPIC_READ) # Höre auf Status-Updates der PLC
    else:
        print(f"[PLC] Fehler beim Verbinden: {rc}")

def on_plc_message(client, userdata, msg):
    """
    PLC sendet Update (z.B. Input I1 geändert).
    Wir analysieren das JSON und senden Updates an die Website.
    """
    global current_inputs
    try:
        raw_msg = msg.payload.decode()
        data = json.loads(raw_msg)
        
        # Wir erwarten Struktur: {"state": {"reported": {"M20": {"value": [1]}, ...}}}
        reported = data.get("state", {}).get("reported", {})

        if not reported:
            return # Leere Nachricht ignorieren

        print(f"[FROM PLC] Status Update: {reported}")

        # --- 1. OUTPUTS (M20-M23) prüfen ---
        feedback_update = {}
        for key in ["M20", "M21", "M22", "M23"]:
            if key in reported:
                # Wert extrahieren (z.B. [1] -> 1)
                val_list = reported[key].get("value", [0])
                val = val_list[0] if isinstance(val_list, list) and len(val_list) > 0 else 0
                feedback_update[key] = val

        # Wenn Outputs dabei waren, an Cloud senden
        if feedback_update:
            client_cloud.publish("plc/feedback", json.dumps(feedback_update))
            print(f"[TO CLOUD] Feedback gesendet: {feedback_update}")

        # --- 2. INPUTS (I1-I8) prüfen ---
        input_changed = False
        for i in range(1, 9):
            key = f"I{i}" # I1, I2, ...
            if key in reported:
                val_list = reported[key].get("value", [0])
                val = val_list[0] if isinstance(val_list, list) and len(val_list) > 0 else 0
                
                # Update lokales Array (Index ist i-1)
                current_inputs[i-1] = val
                input_changed = True
        
        # Wenn Inputs dabei waren, ganzes Array an Cloud senden
        if input_changed:
            client_cloud.publish("plc/inputs", json.dumps(current_inputs))
            print(f"[TO CLOUD] Inputs gesendet: {current_inputs}")

    except Exception as e:
        print(f"[PLC] Parse Error: {e}")


# ==============================================================================
# MAIN SETUP
# ==============================================================================

# 1. Cloud Client Setup (TLS, HiveMQ)
client_cloud = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, "RPI_Gateway_Cloud")
client_cloud.username_pw_set(HIVEMQ_USER, HIVEMQ_PASS)
# Pfad zum Zertifikat (wie in deinem funktionierenden Skript)
client_cloud.tls_set(ca_certs="/etc/ssl/certs/isrgrootx1.pem") 
client_cloud.on_connect = on_cloud_connect
client_cloud.on_message = on_cloud_message

# 2. PLC Client Setup (Lokal, kein TLS)
client_plc = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, "RPI_Gateway_PLC")
client_plc.on_connect = on_plc_connect
client_plc.on_message = on_plc_message


print("Starte System...")

try:
    # Verbinde beide Clients
    print(f"Verbinde zu HiveMQ ({HIVEMQ_BROKER})...")
    client_cloud.connect(HIVEMQ_BROKER, 8883)
    
    print(f"Verbinde zu PLC ({PLC_IP})...")
    client_plc.connect(PLC_IP, PLC_PORT)

    # Starte Hintergrund-Loops für beide
    client_cloud.loop_start()
    client_plc.loop_start()

    # Hauptschleife hält das Programm am Leben
    while True:
        time.sleep(1)

except KeyboardInterrupt:
    print("\nBeende...")
    client_cloud.loop_stop()
    client_plc.loop_stop()
    client_cloud.disconnect()
    client_plc.disconnect()

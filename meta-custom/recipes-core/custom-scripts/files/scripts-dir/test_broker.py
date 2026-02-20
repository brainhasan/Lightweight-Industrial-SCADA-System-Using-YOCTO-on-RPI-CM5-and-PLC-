#when u use this scrip , you will need to have .env file wich contain the user and password and link zo your broker 

import os
from dotenv import load_dotenv
import paho.mqtt.client as mqtt

# Lädt die Variablen aus der .env Datei
load_dotenv()

user = os.getenv('MQTT_USER')
password = os.getenv('MQTT_PASS')
broker = os.getenv('MQTT_BROKER')


def on1(client, userdata, flags, rc, props=None):
    if(rc==0):
        print("8888888888888888")
    else:
        print("NOT")



client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2)
client.username_pw_set(user, password)


client.tls_set(ca_certs="/etc/ssl/certs/isrgrootx1.pem")
client.on_connect=on1

client.connect(broker, 8883)
client.loop_forever()

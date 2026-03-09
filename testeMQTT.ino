#include <WiFi.h>
#include <PubSubClient.h>


// ====== WIFI ======
const char* ssid = "seu wi-fi";
const char* password = "senha do wi-fi";

// ====== MQTT ======
const char* mqtt_server = "test.mosquitto.org";
const int mqtt_port = 1883;
const char* mqtt_topic = "sensor/teste/stm32";

// ==== UART STM32 ====
HardwareSerial STM(1);
WiFiClient espClient;
PubSubClient client(espClient);

// ===== buffers =====
char uartBuffer[150];
int uartIndex = 0;

// ====== Conecta WiFi ======
void setup_wifi(){
  Serial.println("Conectando ao WiFi...");
  WiFi.begin(ssid, password);
  while(WiFi.status() != WL_CONNECTED){
    delay(200);
    Serial.print(".");
  }
  Serial.println("\nWiFi conectado!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
}


// ====== Reconecta MQTT ======
void reconnect(){
  while(!client.connected()){
    Serial.println("Conectando ao MQTT...");

    String clientId = "ESP32-C3";
    clientId += String(random(0xffff), HEX);

    if(client.connect(clientId.c_str())){
      Serial.println("MQTT conectado!");
    }else{
      Serial.print("Falhou, rc=");
      Serial.print(client.state());
      delay(100);
    }
  }
}


void setup(){
  Serial.begin(115200);
  STM.setRxBufferSize(1024);
  STM.begin(115200, SERIAL_8N1, 4, 5);

  setup_wifi();

  client.setServer(mqtt_server, mqtt_port);


}


void loop(){
  if(!client.connected())reconnect();
  client.loop();

  // ===== leitura UART STM32 =====
  while(STM.available()){
    char c = STM.read();
    Serial.print(c);
    if(c == '\r') continue;
    if(c == '\n'){
      uartBuffer[uartIndex] = '\0';
      client.publish(mqtt_topic, uartBuffer);
      Serial.println(uartBuffer);
      uartIndex = 0;
    }else{
      if(uartIndex < sizeof(uartBuffer) - 1){
        uartBuffer[uartIndex++] = c;
      }
    }
  }  
}
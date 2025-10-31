/**
 * NODE-02 FINALIZADO - Arduino Nano + ENC28J60 + HC-SR04
 * Sistema de monitoramento de nível - usa NewPing para maior precisão
 * @version 3.1 - Produção (com NewPing)
 * @date 2025-10-30
 */

#include <UIPEthernet.h>
#include <NewPing.h>

// ============================================================================
// CONFIGURAÇÃO
// ============================================================================
// Rede
byte mac[] = {0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0x02};
IPAddress ip(192, 168, 0, 202);
IPAddress server(192, 168, 0, 101);

// Pinos HC-SR04
#define TRIGGER_PIN 6
#define ECHO_PIN 5
#define LED_PIN 13
#define MAX_DISTANCE 400  // Distância máxima (cm)

// Timing
#define LEITURA_INTERVAL_MS 3000   // Ler sensor a cada 3 segundos
#define ENVIO_INTERVAL_MS 30000    // Enviar para backend a cada 30 segundos

// ============================================================================
// OBJETOS
// ============================================================================
NewPing sonar(TRIGGER_PIN, ECHO_PIN, MAX_DISTANCE);

// ============================================================================
// VARIÁVEIS GLOBAIS
// ============================================================================
EthernetClient client;
unsigned long lastLeitura = 0;
unsigned long lastEnvio = 0;
unsigned long lastEthCheck = 0;
unsigned int sequence = 0;
int ultimaDistancia = 0;  // Armazena última leitura válida

// ============================================================================
// FUNÇÕES
// ============================================================================

/**
 * Lê distância usando NewPing com mediana de 5 amostras
 * NewPing é mais preciso e filtra ruído automaticamente
 * @return Distância em cm (0 = erro/fora de alcance)
 */
int lerDistancia()
{
    // NewPing tem método ping_median() que faz 5 leituras e retorna mediana
    // Muito mais preciso que média, elimina outliers
    unsigned int distancia_cm = sonar.ping_median(5) / US_ROUNDTRIP_CM;
    
    if (distancia_cm == 0)
    {
        Serial.println(F("TIMEOUT - Fora de alcance ou sensor desconectado"));
        return -1;
    }
    
    Serial.print(F("(mediana 5x) "));
    return distancia_cm;
}

/**
 * Envia dados para FastAPI backend
 * Envia apenas distância bruta em cm
 */
bool enviarDados(int distancia)
{
    Serial.print(F("Conectando..."));
    
    // Tentar conectar (com retry simples)
    if (!client.connect(server, 3000))
    {
        Serial.println(F(" FALHOU!"));
        delay(500);
        
        // Segunda tentativa
        if (!client.connect(server, 3000))
        {
            Serial.println(F(" FALHOU 2x!"));
            return false;
        }
    }
    
    Serial.println(F(" OK"));
    
    // Construir JSON - apenas distância
    String json = "{\"mac_address\":\"AA:BB:CC:DD:EE:02\"";
    json += ",\"readings\":[{\"sensor_id\":1,\"distance_cm\":";
    json += String(distancia);
    json += "}],\"sequence\":";
    json += String(sequence);
    json += ",\"rssi\":-35}";
    
    // HTTP POST
    client.println(F("POST /api/leituras/raw HTTP/1.1"));
    client.println(F("Host: 192.168.0.101"));
    client.println(F("Content-Type: application/json"));
    client.print(F("Content-Length: "));
    client.println(json.length());
    client.println();
    client.println(json);
    
    Serial.print(F("Enviado: "));
    Serial.print(distancia);
    Serial.print(F(" cm (seq "));
    Serial.print(sequence);
    Serial.println(F(")"));
    
    // Aguardar resposta (até 3 segundos)
    unsigned long timeout = millis() + 3000;
    bool success = false;
    
    while (millis() < timeout)
    {
        if (client.available())
        {
            String line = client.readStringUntil('\n');
            Serial.println(line);
            
            // Aceitar HTTP 2xx ou "success"
            if (line.indexOf("HTTP/1") >= 0 && line.indexOf(" 2") >= 0)
            {
                success = true;
                Serial.println(F("✓ HTTP 2xx recebido!"));
                break;
            }
            else if (line.indexOf("success") >= 0)
            {
                success = true;
                Serial.println(F("✓ Success confirmado!"));
                break;
            }
        }
        delay(10);
    }
    
    client.stop();
    
    if (success)
    {
        sequence++;
        return true;
    }
    
    Serial.println(F("⚠ Timeout ou erro"));
    return false;
}

// ============================================================================
// SETUP
// ============================================================================
void setup()
{
    Serial.begin(9600);
    delay(1000);
    
    Serial.println(F("\n=== NODE-02 v3.1 (NewPing) ==="));
    Serial.println(F("MAC: AA:BB:CC:DD:EE:02"));
    
    // Configurar pinos
    pinMode(LED_PIN, OUTPUT);
    
    // LED: 3 piscadas = iniciando
    for (int i = 0; i < 3; i++)
    {
        digitalWrite(LED_PIN, HIGH);
        delay(200);
        digitalWrite(LED_PIN, LOW);
        delay(200);
    }
    
    // Inicializar Ethernet
    Serial.print(F("Ethernet..."));
    Ethernet.begin(mac, ip);
    delay(1500);  // Aguardar estabilização
    
    Serial.print(F(" IP: "));
    Serial.println(Ethernet.localIP());
    Serial.println(F("Server: "));
    Serial.println(server);
    
    // LED longo = Ethernet OK
    digitalWrite(LED_PIN, HIGH);
    delay(1000);
    digitalWrite(LED_PIN, LOW);
    
    Serial.println(F("\nConfiguracao:"));
    Serial.println(F("- Leitura: a cada 3s"));
    Serial.println(F("- Envio: a cada 30s\n"));
}

// ============================================================================
// LOOP
// ============================================================================
void loop()
{
    unsigned long now = millis();
    
    // Manter link Ethernet ativo (a cada 10s)
    if (now - lastEthCheck > 10000)
    {
        Ethernet.maintain();
        lastEthCheck = now;
    }
    
    // ========== LEITURA DO SENSOR (a cada 5s) ==========
    if (now - lastLeitura >= LEITURA_INTERVAL_MS)
    {
        lastLeitura = now;
        
        Serial.print(F("["));
        Serial.print(millis() / 1000);
        Serial.print(F("s] Lendo... "));
        
        int distancia = lerDistancia();
        
        if (distancia > 0)
        {
            ultimaDistancia = distancia;
            Serial.print(distancia);
            Serial.println(F(" cm"));
        }
        else
        {
            Serial.println(F("ERRO"));
        }
    }
    
    // ========== ENVIO PARA BACKEND (a cada 30s) ==========
    if (now - lastEnvio >= ENVIO_INTERVAL_MS)
    {
        lastEnvio = now;
        
        if (ultimaDistancia == 0)
        {
            Serial.println(F("\n✗ Sem dados válidos para enviar\n"));
            return;
        }
        
        digitalWrite(LED_PIN, HIGH);
        
        Serial.print(F("\n>>> ENVIANDO "));
        Serial.print(ultimaDistancia);
        Serial.println(F(" cm <<<"));
        
        bool ok = enviarDados(ultimaDistancia);
        
        if (!ok)
        {
            Serial.println(F("✗ Falha no envio!"));
            // Piscar 2x = erro de rede
            for (int i = 0; i < 2; i++)
            {
                digitalWrite(LED_PIN, LOW);
                delay(200);
                digitalWrite(LED_PIN, HIGH);
                delay(200);
            }
        }
        else
        {
            Serial.println(F("✓ Enviado com sucesso!\n"));
        }
        
        digitalWrite(LED_PIN, LOW);
    }
    
    delay(100);  // Pequeno delay para não sobrecarregar
}

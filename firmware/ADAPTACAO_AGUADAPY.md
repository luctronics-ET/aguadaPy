# 🔄 Adaptação Firmwares para aguadaPy

## ✅ Mudanças Aplicadas

### Gateway WiFi ESP32-C3

**Arquivo**: `gateway_wifi/main/main.c`

```c
// ANTES (sistema original)
#define BACKEND_URL "http://192.168.1.101/aguada/api_gateway_v2.php"

// DEPOIS (aguadaPy Docker)
#define BACKEND_URL "http://192.168.1.100:3000/api/leituras/raw"
```

### Configuração Global

**Arquivo**: `common/aguada_config.h`

```c
// ANTES
#define DEFAULT_BACKEND_URL "http://192.168.0.101:8765/api/sensor-data"

// DEPOIS
#define DEFAULT_BACKEND_URL "http://192.168.1.100:3000/api/leituras/raw"
```

---

## 📡 Compatibilidade de Protocolo

### Estrutura sensor_packet_t (NÃO MUDOU)

```c
typedef struct __attribute__((packed)) {
    uint8_t  mac[6];        // MAC address (6 bytes)
    uint8_t  value_id;      // ID do sensor (1 byte)
    uint16_t distance_cm;   // Distância em cm (2 bytes)
    uint16_t sequence;      // Número sequencial (2 bytes)
    int8_t   rssi;          // RSSI em dBm (1 byte)
    uint8_t  reserved;      // Reservado (1 byte)
} sensor_packet_t; // Total: 12 bytes
```

### Gateway → Backend (JSON)

O gateway converte `sensor_packet_t` para JSON antes de enviar:

```json
{
  "mac": "34:85:18:9A:2B:F4",
  "value_id": 1,
  "distance_cm": 125,
  "sequence": 1523,
  "rssi": -65
}
```

### Backend FastAPI

Endpoint: `POST /api/leituras/raw`

Aceita tanto JSON quanto form-data (compatibilidade total com PHP antigo):

```python
# Campos reconhecidos:
- mac / mac_address
- value_id / sensor_id
- distance_cm / valor
- sequence
- rssi
```

---

## 🔧 Como Recompilar

### Gateway WiFi (ESP-IDF)

```bash
cd /opt/lampp/htdocs/aguadaPy/firmware2/gateway_wifi

# Limpar build anterior
rm -rf build

# Configurar (se necessário)
idf.py menuconfig

# Compilar
idf.py build

# Flash no ESP32-C3
idf.py -p /dev/ttyUSB0 flash monitor
```

### NODE-01-CON (ESP32 ESP-NOW)

```bash
cd /opt/lampp/htdocs/aguadaPy/firmware2/node-01-con

# Limpar
rm -rf build

# Compilar
idf.py build

# Flash
idf.py -p /dev/ttyUSB0 flash monitor
```

**⚠️ NODE-01 NÃO precisa mudanças!** Ele envia via ESP-NOW para o gateway, que faz o POST HTTP.

---

## 📝 Checklist de Deploy

### 1. Backend (Docker)

- [x] Criar `docker-compose.yml`
- [x] Criar backend FastAPI
- [x] Endpoint `/api/leituras/raw` compatível
- [ ] Executar `./deploy.sh start`
- [ ] Verificar logs: `docker logs -f aguada_backend`

### 2. Banco de Dados

- [ ] Executar `schema.sql`
- [ ] Executar `functions.sql`
- [ ] Executar `triggers.sql`
- [ ] Executar `seeds.sql`
- [ ] Validar: `SELECT * FROM supervisorio.sensores;`

### 3. Gateway ESP32

- [x] Atualizar `BACKEND_URL` para `192.168.1.100:3000`
- [ ] Recompilar firmware
- [ ] Flash no ESP32-C3
- [ ] Conectar ao WiFi "TP-LINK_BE3344" ou "luciano"
- [ ] Verificar logs: `idf.py monitor`

### 4. Nodes ESP32 (NODE-01, NODE-03)

- [ ] **NÃO precisam mudanças!** (enviam via ESP-NOW para gateway)
- [ ] Apenas verificar se estão funcionando
- [ ] Monitorar sequência de pacotes

### 5. Teste End-to-End

```bash
# 1. Backend rodando
curl http://192.168.1.100:3000/health
# Deve retornar: {"status": "healthy", "database": "connected"}

# 2. NODE-01 envia pacote → Gateway → Backend
# Monitorar logs do backend:
docker logs -f aguada_backend | grep "Leitura recebida"

# 3. Verificar no banco
docker exec -it aguada_postgres psql -U aguada_user -d aguada_cmms -c \
  "SELECT * FROM supervisorio.leituras_raw ORDER BY timestamp DESC LIMIT 10;"

# 4. Ver trigger automático processando
docker exec -it aguada_postgres psql -U aguada_user -d aguada_cmms -c \
  "SELECT * FROM supervisorio.leituras_processadas ORDER BY timestamp_fim DESC LIMIT 5;"
```

---

## 🌐 Configuração de Rede

### Opção 1: IP Fixo no PC (Recomendado)

```bash
# Configurar IP fixo 192.168.1.100 no PC onde roda Docker
sudo nano /etc/network/interfaces

# Adicionar:
auto eth0
iface eth0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
```

### Opção 2: Alterar IP no Firmware

Se o PC tiver outro IP (ex: 192.168.1.50):

```c
// gateway_wifi/main/main.c
#define BACKEND_URL "http://192.168.1.50:3000/api/leituras/raw"
```

Recompilar e fazer flash.

---

## 🐛 Troubleshooting

### Gateway não conecta ao WiFi

```bash
# Ver logs do gateway
idf.py monitor

# Verificar SSIDs disponíveis
# No código: "TP-LINK_BE3344" (sem senha) ou "luciano" (senha: 19852012)
```

### Backend não recebe dados

```bash
# 1. Verificar se backend está rodando
docker ps | grep aguada

# 2. Verificar logs
docker logs -f aguada_backend

# 3. Testar endpoint manualmente
curl -X POST http://192.168.1.100:3000/api/leituras/raw \
  -H "Content-Type: application/json" \
  -d '{"mac":"AA:BB:CC:DD:EE:FF","value_id":1,"distance_cm":123,"sequence":1,"rssi":-60}'

# Deve retornar: {"status":"success", ...}
```

### Sensor não encontrado (404)

```bash
# Verificar se sensor está cadastrado no banco
docker exec -it aguada_postgres psql -U aguada_user -d aguada_cmms -c \
  "SELECT * FROM supervisorio.sensores WHERE value_id = 1;"

# Se não existir, executar seeds.sql ou inserir manualmente
```

---

## 📊 Monitoramento em Produção

### Logs do Backend

```bash
# Tempo real
docker logs -f aguada_backend

# Últimas 100 linhas
docker logs --tail 100 aguada_backend

# Filtrar erros
docker logs aguada_backend 2>&1 | grep ERROR
```

### Logs do Gateway (Serial)

```bash
# ESP-IDF monitor
cd firmware2/gateway_wifi
idf.py monitor

# Procurar:
# ✅ WiFi conectado
# ✅ Pacote recebido
# ✅ HTTP POST enviado
# ✅ Resposta 201
```

### Logs do NODE-01 (Serial)

```bash
cd firmware2/node-01-con
idf.py monitor

# Procurar:
# 📏 Distância: XX cm
# 📤 Enviando: seq=N, value_id=1, dist=XX
# ✅ ESP-NOW enviado com sucesso
```

---

## 🔄 Atualizações Futuras

### Mudança de IP do Servidor

1. Editar `firmware2/gateway_wifi/main/main.c`
2. Alterar `BACKEND_URL`
3. Recompilar e flash

OU (mais fácil):

1. Usar WiFi provisioning para configurar URL via NVS
2. Gateway lê URL do NVS em vez de #define

### Adicionar Novo Sensor (value_id)

1. Inserir no banco:
```sql
INSERT INTO supervisorio.sensores 
(elemento_id, tipo_sensor, value_id, unidade_medida)
VALUES (1, 'NIVEL', 5, 'cm');
```

2. Firmware do node deve enviar `value_id = 5`
3. Backend reconhece automaticamente

---

## ✅ Status Atual

- [x] Backend FastAPI criado
- [x] Endpoint `/api/leituras/raw` compatível
- [x] Firmware gateway atualizado (URL)
- [x] Firmwares node NÃO precisam mudanças
- [x] Protocolo `sensor_packet_t` mantido
- [x] Docker configurado
- [ ] Testar end-to-end NODE→Gateway→Backend→DB

---

**Data**: 2025-10-30  
**Sistema**: aguadaPy V1.0  
**Firmware**: Aguada V2.1 (compatível)

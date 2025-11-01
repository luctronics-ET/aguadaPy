# 🔍 DIAGNÓSTICO DO GATEWAY WIFI - AGUADAPY

**Data**: 01 de Novembro de 2025 às 00:09 (UTC-03:00)  
**Status**: Gateway conectado, aguardando configuração de sensores

---

## ✅ VERIFICAÇÕES REALIZADAS

### 1. Hardware
- ✅ **Gateway conectado**: `/dev/ttyACM0`
- ✅ **Permissões**: Usuário no grupo `plugdev`
- ✅ **Porta acessível**: `crw-rw----+ 1 root plugdev`

### 2. Backend
- ✅ **API Online**: HTTP 200 em `/health`
- ✅ **Endpoint funcionando**: `/api/leituras/raw` responde
- ✅ **PostgreSQL**: Container rodando
- ✅ **Banco de dados**: 21 leituras, 3 sensores cadastrados

### 3. Firmware do Gateway
- ✅ **Arquivo**: `firmware/gateway_wifi/main/main.c`
- ✅ **Backend URL**: `http://192.168.0.101:3000/api/leituras/raw`
- ✅ **WiFi Networks**: 2 redes configuradas
  - `TP-LINK_BE3344` (sem senha)
  - `luciano` (senha: 19852012)
- ✅ **WiFi Channel**: 11
- ✅ **ESP-NOW**: Configurado para receber de nodes

---

## ⚠️ PROBLEMA IDENTIFICADO

### Sensores Não Cadastrados

O backend **exige que os sensores estejam cadastrados** antes de aceitar leituras.

**Erro retornado**:
```json
{
  "detail": "Sensor com MAC=AA:BB:CC:DD:EE:FF e value_id=1 não encontrado. Cadastre o sensor primeiro."
}
```

**Causa**:
O endpoint `/api/leituras/raw` busca o sensor pelo MAC address no campo `meta->>'mac_address'` da tabela `supervisorio.sensores`.

**Código relevante** (`backend/src/api/leituras.py` linha 95-114):
```python
cursor.execute("""
    SELECT sensor_id, elemento_id, tipo
    FROM supervisorio.sensores
    WHERE meta->>'mac_address' = %s
       OR sensor_id = CONCAT('SEN_VAL_', %s::text)
    LIMIT 1
""", (mac, value_id))

sensor = cursor.fetchone()

if not sensor:
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"Sensor com MAC={mac} e value_id={value_id} não encontrado. Cadastre o sensor primeiro."
    )
```

---

## 📊 SENSORES JÁ CADASTRADOS

```
    sensor_id     | elemento_id | tipo  | mac_address
------------------+-------------+-------+------------------
 SEN_NODE01_NIVEL |          27 | NIVEL | DC:06:75:67:6A:CC
 SEN_NODE03_NIVEL |          28 | NIVEL | 20:6E:F1:6B:77:58
 SEN_NODE02_NIVEL |          29 | NIVEL | AA:BB:CC:DD:EE:02
```

**Últimas leituras**:
- NODE02: 100.000 cm (2025-10-30 19:03:13)
- NODE01: 51.000 cm (2025-10-30 18:03:26)

---

## 🔧 SOLUÇÕES

### Solução 1: Cadastrar Sensores Manualmente

Use o script `cadastrar_sensor.sh`:

```bash
# Sintaxe
./cadastrar_sensor.sh <MAC_ADDRESS> <VALUE_ID> <NOME_SENSOR> [ELEMENTO_ID]

# Exemplo: Cadastrar NODE04
./cadastrar_sensor.sh 'AA:BB:CC:DD:EE:04' 1 'SEN_NODE04_NIVEL' 27

# Exemplo: Cadastrar NODE05
./cadastrar_sensor.sh 'BB:CC:DD:EE:FF:05' 1 'SEN_NODE05_NIVEL' 28
```

**Parâmetros**:
- `MAC_ADDRESS`: MAC do ESP32 node (formato: `AA:BB:CC:DD:EE:FF`)
- `VALUE_ID`: ID do valor (1 = nível principal)
- `NOME_SENSOR`: Nome único do sensor (ex: `SEN_NODE04_NIVEL`)
- `ELEMENTO_ID`: ID do elemento/reservatório (27 = RES_CONS, 28 = RES_INC, 29 = RES_B03)

---

### Solução 2: Modificar Backend para Auto-Cadastro

**Opção A**: Criar sensor automaticamente quando não existir

Modificar `backend/src/api/leituras.py` linha 105-114:

```python
if not sensor:
    # Criar sensor automaticamente
    logger.warning(f"⚠️  Auto-criando sensor: mac={mac}, value_id={value_id}")
    
    cursor.execute("""
        INSERT INTO supervisorio.sensores (
            sensor_id, elemento_id, tipo, modelo, unidade, 
            estado_operacional, meta
        ) VALUES (
            %s, 27, 'NIVEL', 'HC-SR04', 'cm', 'ativo',
            jsonb_build_object('mac_address', %s, 'value_id', %s)
        )
        RETURNING sensor_id, elemento_id
    """, (f"SEN_AUTO_{value_id}", mac, value_id))
    
    sensor = cursor.fetchone()
```

**Opção B**: Usar sensor genérico para MACs desconhecidos

```python
if not sensor:
    # Usar sensor genérico
    sensor_id = f"SEN_GENERIC_{value_id}"
    elemento_id = 27  # Default: RES_CONS
```

---

### Solução 3: Descobrir MAC dos Nodes

Para descobrir o MAC address dos nodes ESP32:

#### Método 1: Monitor Serial do Gateway

```bash
./monitor_gateway.sh
```

O gateway exibe no log:
```
📥 RX: MAC=AA:BB:CC:DD:EE:FF, seq=123, value_id=1, dist=125 cm, RSSI=-65 dBm
```

#### Método 2: Código do Node

Adicionar no firmware do node:

```cpp
void setup() {
    Serial.begin(115200);
    
    // Exibir MAC address
    uint8_t mac[6];
    esp_read_mac(mac, ESP_MAC_WIFI_STA);
    Serial.printf("MAC: %02X:%02X:%02X:%02X:%02X:%02X\n",
                  mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}
```

#### Método 3: Logs do Backend

Verificar logs do backend:

```bash
docker-compose logs -f backend | grep "MAC="
```

---

## 🚀 PRÓXIMOS PASSOS

### 1. Descobrir MAC dos Nodes Ativos

```bash
# Monitorar gateway
./monitor_gateway.sh

# Em outro terminal, ver logs do backend
docker-compose logs -f backend
```

**Aguardar**: Os nodes enviarem pacotes ESP-NOW para o gateway

**Anotar**: MAC addresses que aparecem nos logs

### 2. Cadastrar Sensores

Para cada node ativo:

```bash
./cadastrar_sensor.sh '<MAC_DO_NODE>' 1 'SEN_NODEXX_NIVEL' 27
```

### 3. Validar Recebimento

```bash
# Testar endpoint
./test_gateway.sh

# Ver últimas leituras
docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -c "
    SELECT sensor_id, valor, datetime 
    FROM supervisorio.leituras_raw 
    ORDER BY datetime DESC 
    LIMIT 10;
"
```

### 4. Monitorar Dashboard

```
http://localhost/dashboard_v2.html
```

Verificar:
- ✅ Cards de consumo atualizando
- ✅ Gráficos com dados
- ✅ Tabela de reservatórios preenchida
- ✅ Mapa com marcadores

---

## 📝 SCRIPTS CRIADOS

### 1. `monitor_gateway.sh`
Monitora logs do gateway via porta serial

```bash
./monitor_gateway.sh
```

### 2. `test_gateway.sh`
Testa conexão gateway → backend → banco

```bash
./test_gateway.sh
```

### 3. `cadastrar_sensor.sh`
Cadastra novos sensores no banco

```bash
./cadastrar_sensor.sh '<MAC>' <VALUE_ID> '<NOME>' [ELEMENTO_ID]
```

### 4. `test_conexoes.sh`
Testa toda a infraestrutura (criado anteriormente)

```bash
./test_conexoes.sh
```

---

## 🔍 COMANDOS ÚTEIS

### Ver Sensores Cadastrados
```bash
docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -c "
    SELECT sensor_id, meta->>'mac_address' as mac, estado_operacional 
    FROM supervisorio.sensores;
"
```

### Ver Últimas Leituras
```bash
docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -c "
    SELECT sensor_id, valor, datetime, observacao 
    FROM supervisorio.leituras_raw 
    ORDER BY datetime DESC 
    LIMIT 10;
"
```

### Ver Logs do Backend
```bash
docker-compose logs -f backend
```

### Ver Logs do Gateway (Serial)
```bash
./monitor_gateway.sh
```

### Testar Envio Manual
```bash
curl -X POST http://localhost:3000/api/leituras/raw \
  -H "Content-Type: application/json" \
  -d '{
    "mac": "DC:06:75:67:6A:CC",
    "value_id": 1,
    "distance_cm": 125,
    "sequence": 9999,
    "rssi": -65
  }'
```

---

## ✅ CHECKLIST DE VALIDAÇÃO

### Infraestrutura
- [x] Gateway conectado na USB
- [x] Backend rodando (porta 3000)
- [x] PostgreSQL rodando
- [x] Frontend acessível (porta 80)

### Configuração
- [x] Firmware do gateway compilado
- [x] Backend URL correta no firmware
- [x] WiFi networks configuradas
- [x] ESP-NOW habilitado

### Sensores
- [ ] MACs dos nodes descobertos
- [ ] Sensores cadastrados no banco
- [ ] Leituras sendo recebidas
- [ ] Dashboard exibindo dados

### Testes
- [x] Health check OK
- [x] Endpoint /api/leituras/raw funcional
- [ ] Gateway enviando dados
- [ ] Dados aparecendo no dashboard

---

## 🎯 STATUS ATUAL

**Gateway**: ✅ Conectado e configurado  
**Backend**: ✅ Online e funcional  
**Banco de Dados**: ✅ Operacional  
**Sensores**: ⚠️ Aguardando cadastro dos MACs  

**Próximo passo**: Descobrir MAC addresses dos nodes ativos e cadastrá-los

---

## 📞 TROUBLESHOOTING

### Problema: Gateway não aparece em /dev/ttyACM0

**Solução**:
```bash
# Verificar portas disponíveis
ls -la /dev/tty* | grep -E "USB|ACM"

# Dar permissão
sudo chmod 666 /dev/ttyACM0

# Adicionar usuário ao grupo
sudo usermod -a -G dialout $USER
sudo usermod -a -G plugdev $USER
```

### Problema: Backend não aceita leituras

**Causa**: Sensor não cadastrado

**Solução**: Cadastrar sensor com `./cadastrar_sensor.sh`

### Problema: Gateway não conecta ao WiFi

**Verificar**:
1. SSID e senha corretos no firmware
2. Rede WiFi no canal 11
3. Logs do gateway: `./monitor_gateway.sh`

### Problema: Nodes não enviam dados

**Verificar**:
1. Nodes ligados e funcionando
2. ESP-NOW configurado no mesmo canal (11)
3. MAC do gateway cadastrado nos nodes
4. Logs do gateway para ver se recebe pacotes

---

**Diagnóstico realizado por**: Cascade AI  
**Data**: 01/11/2025 às 00:09 (UTC-03:00)

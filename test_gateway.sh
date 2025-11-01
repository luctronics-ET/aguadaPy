#!/bin/bash

# ============================================
# Script de Teste do Gateway WiFi
# ============================================

echo "🔍 TESTE DO GATEWAY WIFI - AGUADAPY"
echo "===================================="
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

API_URL="http://localhost:3000"

echo "1️⃣  Verificando Hardware"
echo "------------------------"

# Verificar porta USB
echo -n "Gateway na USB: "
if [ -e "/dev/ttyACM0" ]; then
    echo -e "${GREEN}✅ /dev/ttyACM0${NC}"
    ls -l /dev/ttyACM0
elif [ -e "/dev/ttyUSB0" ]; then
    echo -e "${GREEN}✅ /dev/ttyUSB0${NC}"
    ls -l /dev/ttyUSB0
else
    echo -e "${RED}❌ Não encontrado${NC}"
    echo "Portas disponíveis:"
    ls -la /dev/tty* 2>/dev/null | grep -E "USB|ACM" || echo "Nenhuma"
fi

echo ""
echo "2️⃣  Verificando Backend"
echo "------------------------"

# Verificar se backend está rodando
echo -n "Backend API: "
response=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" 2>/dev/null)
if [ "$response" = "200" ]; then
    echo -e "${GREEN}✅ Online (HTTP $response)${NC}"
else
    echo -e "${RED}❌ Offline (HTTP $response)${NC}"
    echo "Execute: docker-compose up -d"
fi

# Verificar endpoint de leituras
echo -n "Endpoint /api/leituras/raw: "
response=$(curl -s -X POST "$API_URL/api/leituras/raw" \
  -H "Content-Type: application/json" \
  -d '{"mac":"TEST:TEST","value_id":99,"distance_cm":100,"sequence":1,"rssi":-50}' 2>/dev/null)

if echo "$response" | grep -q "success\|leitura_id"; then
    echo -e "${GREEN}✅ Funcionando${NC}"
else
    echo -e "${YELLOW}⚠️  Resposta: $response${NC}"
fi

echo ""
echo "3️⃣  Configuração do Gateway"
echo "----------------------------"

# Ler configuração do main.c
echo "Configurações no firmware:"
if [ -f "firmware/gateway_wifi/main/main.c" ]; then
    echo -e "${CYAN}WiFi Networks:${NC}"
    grep -A 2 "wifi_networks\[\]" firmware/gateway_wifi/main/main.c | grep -E "ssid|password" | head -4
    
    echo ""
    echo -e "${CYAN}Backend URL:${NC}"
    grep "BACKEND_URL" firmware/gateway_wifi/main/main.c
    
    echo ""
    echo -e "${CYAN}WiFi Channel:${NC}"
    grep "WIFI_CHANNEL" firmware/gateway_wifi/main/main.c | head -1
else
    echo -e "${YELLOW}⚠️  Arquivo main.c não encontrado${NC}"
fi

echo ""
echo "4️⃣  Verificando Banco de Dados"
echo "--------------------------------"

# Verificar se PostgreSQL está acessível
echo -n "PostgreSQL: "
if docker ps | grep -q aguada_postgres; then
    echo -e "${GREEN}✅ Container rodando${NC}"
    
    # Verificar tabela de leituras
    echo -n "Tabela leituras_raw: "
    count=$(docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -t -c "SELECT COUNT(*) FROM supervisorio.leituras_raw;" 2>/dev/null | tr -d ' ')
    if [ ! -z "$count" ]; then
        echo -e "${GREEN}✅ $count leituras${NC}"
    else
        echo -e "${RED}❌ Erro ao consultar${NC}"
    fi
    
    # Verificar sensores cadastrados
    echo -n "Sensores cadastrados: "
    sensors=$(docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -t -c "SELECT COUNT(*) FROM supervisorio.sensores;" 2>/dev/null | tr -d ' ')
    if [ ! -z "$sensors" ]; then
        echo -e "${GREEN}✅ $sensors sensores${NC}"
    else
        echo -e "${RED}❌ Erro ao consultar${NC}"
    fi
else
    echo -e "${RED}❌ Container não está rodando${NC}"
fi

echo ""
echo "5️⃣  Teste de Envio Simulado"
echo "----------------------------"

echo "Simulando pacote ESP32 → Backend..."

response=$(curl -s -X POST "$API_URL/api/leituras/raw" \
  -H "Content-Type: application/json" \
  -d '{
    "mac": "AA:BB:CC:DD:EE:FF",
    "value_id": 1,
    "distance_cm": 125,
    "sequence": 9999,
    "rssi": -65
  }')

echo "Resposta do backend:"
echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

echo ""
echo "6️⃣  Últimas Leituras no Banco"
echo "-------------------------------"

if docker ps | grep -q aguada_postgres; then
    docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -c "
        SELECT 
            sensor_id, 
            valor, 
            datetime, 
            observacao 
        FROM supervisorio.leituras_raw 
        ORDER BY datetime DESC 
        LIMIT 5;
    " 2>/dev/null
fi

echo ""
echo "===================================="
echo "✅ TESTE CONCLUÍDO"
echo "===================================="
echo ""
echo "📝 Próximos passos:"
echo "   1. Monitorar gateway: ./monitor_gateway.sh"
echo "   2. Ver logs do backend: docker-compose logs -f backend"
echo "   3. Acessar dashboard: http://localhost/dashboard_v2.html"
echo ""

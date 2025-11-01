#!/bin/bash

# ============================================
# Script de Teste - Conexões Backend/Banco
# ============================================

echo "🔍 TESTE DE CONEXÕES - AGUADAPY"
echo "================================"
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

API_URL="http://localhost:3000"

# Função para testar endpoint
test_endpoint() {
    local endpoint=$1
    local description=$2
    
    echo -n "Testando $description... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL$endpoint" 2>/dev/null)
    
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✅ OK${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED}❌ FALHOU${NC} (HTTP $response)"
        return 1
    fi
}

echo "1️⃣  Testando Health Check"
echo "-------------------------"
test_endpoint "/health" "Health Check"
echo ""

echo "2️⃣  Testando Endpoints de Leituras"
echo "-----------------------------------"
test_endpoint "/api/leituras/processadas?limit=10" "Leituras Processadas"
echo ""

echo "3️⃣  Testando Endpoints de Elementos"
echo "------------------------------------"
test_endpoint "/api/elementos/" "Listar Elementos"
test_endpoint "/api/elementos/coordenadas" "Coordenadas para Mapa"
echo ""

echo "4️⃣  Testando Endpoints de Dashboard"
echo "------------------------------------"
test_endpoint "/api/leituras/ultimas" "Últimas Leituras"
test_endpoint "/api/test" "Test Endpoint"
echo ""

echo "5️⃣  Testando Endpoints de Eventos"
echo "----------------------------------"
test_endpoint "/api/eventos/" "Listar Eventos"
echo ""

echo "6️⃣  Testando Conexão com Banco de Dados"
echo "----------------------------------------"
echo "Verificando se PostgreSQL está acessível..."

if command -v docker &> /dev/null; then
    echo -n "Container PostgreSQL: "
    if docker ps | grep -q aguada_postgres; then
        echo -e "${GREEN}✅ Rodando${NC}"
        
        echo -n "Testando conexão ao banco: "
        docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -c "SELECT 1;" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Conectado${NC}"
            
            echo -n "Verificando schema supervisorio: "
            result=$(docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'supervisorio';" 2>/dev/null | tr -d ' ')
            if [ "$result" -gt 0 ]; then
                echo -e "${GREEN}✅ Existe ($result tabelas)${NC}"
            else
                echo -e "${RED}❌ Não encontrado${NC}"
            fi
        else
            echo -e "${RED}❌ Falha na conexão${NC}"
        fi
    else
        echo -e "${RED}❌ Não está rodando${NC}"
    fi
    
    echo -n "Container Backend: "
    if docker ps | grep -q aguada_backend; then
        echo -e "${GREEN}✅ Rodando${NC}"
    else
        echo -e "${RED}❌ Não está rodando${NC}"
    fi
    
    echo -n "Container Frontend: "
    if docker ps | grep -q aguada_frontend; then
        echo -e "${GREEN}✅ Rodando${NC}"
    else
        echo -e "${RED}❌ Não está rodando${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Docker não encontrado. Pulando verificação de containers.${NC}"
fi

echo ""
echo "7️⃣  Testando POST de Leitura (Simular ESP32)"
echo "---------------------------------------------"
echo "Enviando leitura de teste..."

response=$(curl -s -X POST "$API_URL/api/leituras/raw" \
  -H "Content-Type: application/json" \
  -d '{
    "mac": "AA:BB:CC:DD:EE:FF",
    "value_id": 1,
    "distance_cm": 125,
    "sequence": 9999,
    "rssi": -65
  }' 2>/dev/null)

if echo "$response" | grep -q "success\|leitura_id"; then
    echo -e "${GREEN}✅ Leitura enviada com sucesso${NC}"
    echo "Resposta: $response"
else
    echo -e "${RED}❌ Erro ao enviar leitura${NC}"
    echo "Resposta: $response"
fi

echo ""
echo "================================"
echo "✅ TESTE CONCLUÍDO"
echo "================================"
echo ""
echo "📝 Próximos passos:"
echo "   1. Se algum teste falhou, verifique os logs: docker-compose logs -f"
echo "   2. Acesse o dashboard: http://localhost/dashboard.html"
echo "   3. Verifique o console do navegador (F12)"
echo ""

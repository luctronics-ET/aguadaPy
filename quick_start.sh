#!/bin/bash
#
# Quick Start Guide - Sistema aguadaPy
# Teste rápido do sistema completo
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  aguadaPy - Quick Start Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Verificar Docker
echo -e "${YELLOW}[1/7]${NC} Verificando Docker..."
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker não instalado!${NC}"
    echo "Instale com: curl -fsSL https://get.docker.com | sh"
    exit 1
fi
echo -e "${GREEN}✅ Docker OK${NC}"
echo ""

# 2. Iniciar containers
echo -e "${YELLOW}[2/7]${NC} Iniciando containers Docker..."
./deploy.sh start
echo ""

# 3. Aguardar PostgreSQL estar pronto
echo -e "${YELLOW}[3/7]${NC} Aguardando PostgreSQL inicializar..."
sleep 10

# Testar conexão
if docker exec aguada_postgres pg_isready -U aguada_user -d aguada_cmms &> /dev/null; then
    echo -e "${GREEN}✅ PostgreSQL pronto!${NC}"
else
    echo -e "${RED}❌ PostgreSQL não está respondendo${NC}"
    echo "Tente: docker logs aguada_postgres"
    exit 1
fi
echo ""

# 4. Verificar tabelas
echo -e "${YELLOW}[4/7]${NC} Verificando estrutura do banco..."
TABLES=$(docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='supervisorio';")

if [ "$TABLES" -ge "15" ]; then
    echo -e "${GREEN}✅ $TABLES tabelas encontradas no schema supervisorio${NC}"
else
    echo -e "${RED}❌ Tabelas insuficientes ($TABLES). Execute os scripts SQL:${NC}"
    echo "   docker exec -i aguada_postgres psql -U aguada_user -d aguada_cmms < database/schema.sql"
    echo "   docker exec -i aguada_postgres psql -U aguada_user -d aguada_cmms < database/functions.sql"
    echo "   docker exec -i aguada_postgres psql -U aguada_user -d aguada_cmms < database/triggers.sql"
    echo "   docker exec -i aguada_postgres psql -U aguada_user -d aguada_cmms < database/seeds.sql"
    exit 1
fi
echo ""

# 5. Testar Backend API
echo -e "${YELLOW}[5/7]${NC} Testando Backend API..."
sleep 5  # Aguardar backend iniciar

HEALTH=$(curl -s http://localhost:3000/health | grep -o '"status":"healthy"' || echo "")
if [ -n "$HEALTH" ]; then
    echo -e "${GREEN}✅ Backend API respondendo!${NC}"
    echo "   URL: http://localhost:3000"
else
    echo -e "${RED}❌ Backend não está respondendo${NC}"
    echo "Logs: docker logs aguada_backend"
    exit 1
fi
echo ""

# 6. Testar endpoint de leituras
echo -e "${YELLOW}[6/7]${NC} Testando endpoint POST /api/leituras/raw..."

RESPONSE=$(curl -s -X POST http://localhost:3000/api/leituras/raw \
  -H "Content-Type: application/json" \
  -d '{
    "mac": "AA:BB:CC:DD:EE:FF",
    "value_id": 1,
    "distance_cm": 123,
    "sequence": 9999,
    "rssi": -60
  }')

if echo "$RESPONSE" | grep -q '"status":"success"'; then
    echo -e "${GREEN}✅ Endpoint de leituras funcionando!${NC}"
    echo "   Resposta: $RESPONSE"
else
    echo -e "${YELLOW}⚠️  Endpoint respondeu, mas pode faltar sensor cadastrado${NC}"
    echo "   Resposta: $RESPONSE"
    echo ""
    echo "   Execute seeds.sql para popular sensores de exemplo:"
    echo "   docker exec -i aguada_postgres psql -U aguada_user -d aguada_cmms < database/seeds.sql"
fi
echo ""

# 7. Resumo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  ✅ SISTEMA PRONTO!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Acessos:${NC}"
echo "   🌐 Backend API: http://localhost:3000"
echo "   📊 API Docs: http://localhost:3000/docs"
echo "   🗄️  PostgreSQL: localhost:5432"
echo "   👤 User: aguada_user"
echo "   🔑 Password: aguada_pass_2025"
echo ""
echo -e "${GREEN}Comandos úteis:${NC}"
echo "   ./deploy.sh logs     # Ver logs em tempo real"
echo "   ./deploy.sh status   # Status dos containers"
echo "   ./deploy.sh stop     # Parar sistema"
echo ""
echo -e "${GREEN}Próximos passos:${NC}"
echo "   1. Compilar firmware do gateway:"
echo "      cd firmware2/gateway_wifi && idf.py build"
echo ""
echo "   2. Flash no ESP32-C3:"
echo "      idf.py -p /dev/ttyUSB0 flash monitor"
echo ""
echo "   3. Ligar NODE-01 (ESP-NOW) para testar comunicação"
echo ""
echo "   4. Monitorar leituras:"
echo "      docker logs -f aguada_backend | grep 'Leitura recebida'"
echo ""

exit 0

#!/bin/bash

# ============================================
# Script de Monitoramento do Gateway WiFi
# ============================================

echo "🌐 MONITOR DO GATEWAY WIFI - AGUADAPY"
echo "====================================="
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Porta serial
PORT="/dev/ttyACM0"
BAUD_RATE="115200"

# Verificar se a porta existe
if [ ! -e "$PORT" ]; then
    echo -e "${RED}❌ Porta $PORT não encontrada!${NC}"
    echo ""
    echo "Portas disponíveis:"
    ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "Nenhuma porta USB encontrada"
    exit 1
fi

# Verificar permissões
if [ ! -r "$PORT" ] || [ ! -w "$PORT" ]; then
    echo -e "${YELLOW}⚠️  Sem permissão para acessar $PORT${NC}"
    echo "Execute: sudo chmod 666 $PORT"
    echo "Ou adicione seu usuário ao grupo dialout/plugdev"
    exit 1
fi

echo -e "${GREEN}✅ Gateway conectado em: $PORT${NC}"
echo -e "${BLUE}📊 Baud Rate: $BAUD_RATE${NC}"
echo ""
echo "Monitorando logs do gateway..."
echo "Pressione Ctrl+C para sair"
echo "-----------------------------------"
echo ""

# Verificar se screen está instalado
if command -v screen &> /dev/null; then
    # Usar screen
    screen -L -Logfile gateway.log $PORT $BAUD_RATE
elif command -v minicom &> /dev/null; then
    # Usar minicom
    minicom -D $PORT -b $BAUD_RATE
elif command -v picocom &> /dev/null; then
    # Usar picocom
    picocom -b $BAUD_RATE $PORT
elif command -v cat &> /dev/null; then
    # Fallback: usar cat (somente leitura)
    echo -e "${YELLOW}⚠️  Instalando stty para configurar porta...${NC}"
    stty -F $PORT $BAUD_RATE raw -echo
    echo -e "${GREEN}✅ Lendo dados da porta serial:${NC}"
    echo ""
    cat $PORT
else
    echo -e "${RED}❌ Nenhum monitor serial encontrado!${NC}"
    echo "Instale um dos seguintes:"
    echo "  - sudo apt install screen"
    echo "  - sudo apt install minicom"
    echo "  - sudo apt install picocom"
    exit 1
fi

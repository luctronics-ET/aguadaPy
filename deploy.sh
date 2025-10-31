#!/bin/bash
#
# Script de Deploy - Sistema Aguada CMMS/BMS
# Uso: ./deploy.sh [start|stop|restart|logs|status]
#

set -e

PROJECT_NAME="aguada-cmms"
COMPOSE_FILE="docker-compose.yml"

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Sistema Aguada CMMS/BMS - Deploy${NC}"
echo -e "${GREEN}========================================${NC}"

# Verificar se Docker está instalado
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker não encontrado!${NC}"
    echo "Instale com: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose não encontrado!${NC}"
    echo "Instale com: sudo apt install docker-compose"
    exit 1
fi

# Função: Iniciar sistema
start_system() {
    echo -e "${YELLOW}🚀 Iniciando containers...${NC}"
    
    # Criar arquivo .env se não existir
    if [ ! -f .env ]; then
        echo -e "${YELLOW}⚠️  Arquivo .env não encontrado. Criando a partir de .env.example...${NC}"
        cp .env.example .env
        echo -e "${RED}⚠️  ATENÇÃO: Edite o arquivo .env e altere JWT_SECRET e senhas!${NC}"
        read -p "Pressione ENTER para continuar..."
    fi
    
    # Build e start
    docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME up -d --build
    
    echo ""
    echo -e "${GREEN}✅ Sistema iniciado com sucesso!${NC}"
    echo ""
    echo "📊 Acessos:"
    echo "   Dashboard: http://localhost"
    echo "   API: http://localhost:3000"
    echo "   PostgreSQL: localhost:5432"
    echo ""
    echo "📝 Logs: docker-compose -p $PROJECT_NAME logs -f"
}

# Função: Parar sistema
stop_system() {
    echo -e "${YELLOW}🛑 Parando containers...${NC}"
    docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME down
    echo -e "${GREEN}✅ Sistema parado!${NC}"
}

# Função: Reiniciar sistema
restart_system() {
    echo -e "${YELLOW}🔄 Reiniciando sistema...${NC}"
    stop_system
    sleep 2
    start_system
}

# Função: Ver logs
show_logs() {
    docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME logs -f --tail=100
}

# Função: Status
show_status() {
    echo -e "${YELLOW}📊 Status dos containers:${NC}"
    docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME ps
    echo ""
    echo -e "${YELLOW}💾 Volumes:${NC}"
    docker volume ls | grep $PROJECT_NAME || echo "Nenhum volume encontrado"
}

# Menu principal
case "$1" in
    start)
        start_system
        ;;
    stop)
        stop_system
        ;;
    restart)
        restart_system
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|logs|status}"
        echo ""
        echo "Comandos:"
        echo "  start   - Inicia o sistema"
        echo "  stop    - Para o sistema"
        echo "  restart - Reinicia o sistema"
        echo "  logs    - Mostra logs em tempo real"
        echo "  status  - Mostra status dos containers"
        exit 1
        ;;
esac

exit 0

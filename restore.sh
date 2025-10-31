#!/bin/bash
#
# Script de Restore - Sistema Aguada CMMS/BMS
# Restaura backup completo de pendrive
# Uso: ./restore.sh [arquivo_backup.tar.gz]
#

set -e

PROJECT_NAME="aguada-cmms"
BACKUP_FILE="$1"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Restore Sistema Aguada CMMS/BMS${NC}"
echo -e "${GREEN}========================================${NC}"

# Verificar arquivo de backup
if [ -z "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Erro: Informe o arquivo de backup!${NC}"
    echo "Uso: $0 arquivo_backup.tar.gz"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Erro: Arquivo $BACKUP_FILE não encontrado!${NC}"
    exit 1
fi

# Confirmar restore
echo -e "${YELLOW}⚠️  ATENÇÃO: Este processo irá sobrescrever dados existentes!${NC}"
read -p "Deseja continuar? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Restore cancelado."
    exit 0
fi

# Diretório temporário
RESTORE_DIR=$(mktemp -d)
echo -e "${YELLOW}📁 Extraindo backup em: $RESTORE_DIR${NC}"

# Extrair backup
tar xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

# Parar containers se estiverem rodando
echo -e "${YELLOW}🛑 Parando containers existentes...${NC}"
docker-compose -p $PROJECT_NAME down 2>/dev/null || true

# Remover volumes antigos (CUIDADO!)
echo -e "${YELLOW}🗑️  Removendo volumes antigos...${NC}"
docker volume rm ${PROJECT_NAME}_postgres_data 2>/dev/null || true

# Criar volume novo
echo -e "${YELLOW}📦 Criando volume PostgreSQL...${NC}"
docker volume create ${PROJECT_NAME}_postgres_data

# Restaurar volume
echo -e "${YELLOW}💾 Restaurando dados do PostgreSQL...${NC}"
docker run --rm \
    -v ${PROJECT_NAME}_postgres_data:/data \
    -v "$RESTORE_DIR":/backup \
    alpine tar xzf /backup/postgres_volume.tar.gz -C /data

# Copiar configurações
echo -e "${YELLOW}⚙️  Restaurando configurações...${NC}"
cp "$RESTORE_DIR/docker-compose.yml" ./
cp "$RESTORE_DIR/.env" ./

# Iniciar containers
echo -e "${YELLOW}🚀 Iniciando containers...${NC}"
docker-compose -p $PROJECT_NAME up -d

# Aguardar PostgreSQL estar pronto
echo -e "${YELLOW}⏳ Aguardando PostgreSQL inicializar...${NC}"
sleep 10

# Restaurar dump SQL (caso necessário)
if [ -f "$RESTORE_DIR/database_dump.sql" ]; then
    echo -e "${YELLOW}📥 Importando dump SQL...${NC}"
    docker exec -i aguada_postgres psql -U aguada_user aguada_cmms < "$RESTORE_DIR/database_dump.sql" || true
fi

# Limpar temporários
rm -rf "$RESTORE_DIR"

# Informações finais
echo ""
echo -e "${GREEN}✅ Restore concluído com sucesso!${NC}"
echo ""
echo "📊 Sistema restaurado e rodando!"
echo "   Dashboard: http://localhost"
echo "   API: http://localhost:3000"
echo ""
echo "📝 Verifique os logs: docker-compose -p $PROJECT_NAME logs -f"
echo ""

exit 0

#!/bin/bash
#
# Script de Backup - Sistema Aguada CMMS/BMS
# Gera backup completo para transferência via pendrive
# Uso: ./backup.sh [diretorio_destino]
#

set -e

PROJECT_NAME="aguada-cmms"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${1:-./backups}"
BACKUP_FILE="aguada_backup_${TIMESTAMP}.tar.gz"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Backup Sistema Aguada CMMS/BMS${NC}"
echo -e "${GREEN}========================================${NC}"

# Criar diretório de backup
mkdir -p "$BACKUP_DIR"

# Diretório temporário
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}📁 Diretório temporário: $TEMP_DIR${NC}"

# 1. Backup do banco de dados
echo -e "${YELLOW}💾 Fazendo backup do PostgreSQL...${NC}"
docker exec aguada_postgres pg_dump -U aguada_user aguada_cmms > "$TEMP_DIR/database_dump.sql"

# 2. Exportar volumes Docker
echo -e "${YELLOW}📦 Exportando volumes Docker...${NC}"
docker run --rm \
    -v ${PROJECT_NAME}_postgres_data:/data \
    -v "$TEMP_DIR":/backup \
    alpine tar czf /backup/postgres_volume.tar.gz -C /data .

# 3. Copiar arquivos de configuração
echo -e "${YELLOW}⚙️  Copiando configurações...${NC}"
cp docker-compose.yml "$TEMP_DIR/"
cp .env "$TEMP_DIR/" 2>/dev/null || cp .env.example "$TEMP_DIR/.env"

# 4. Copiar logs (últimos 7 dias)
if [ -d "./logs" ]; then
    echo -e "${YELLOW}📝 Copiando logs...${NC}"
    find ./logs -mtime -7 -type f -exec cp {} "$TEMP_DIR/" \;
fi

# 5. Informações do sistema
echo -e "${YELLOW}ℹ️  Gerando informações do sistema...${NC}"
cat > "$TEMP_DIR/backup_info.txt" <<EOF
Backup Sistema Aguada CMMS/BMS
==============================
Data: $(date)
Host: $(hostname)
Docker Compose versão: $(docker-compose --version)
PostgreSQL versão: $(docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -c "SELECT version();" | head -3 | tail -1)

Containers em execução:
$(docker-compose -p $PROJECT_NAME ps)

Volumes:
$(docker volume ls | grep $PROJECT_NAME)

Instruções de Restore:
======================
1. Copie este backup para o PC de destino
2. Descompacte: tar -xzf $BACKUP_FILE
3. Execute: ./restore.sh aguada_backup_${TIMESTAMP}
EOF

# 6. Compactar tudo
echo -e "${YELLOW}🗜️  Compactando backup...${NC}"
tar czf "$BACKUP_DIR/$BACKUP_FILE" -C "$TEMP_DIR" .

# Limpar temporários
rm -rf "$TEMP_DIR"

# Informações finais
BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
echo ""
echo -e "${GREEN}✅ Backup concluído com sucesso!${NC}"
echo ""
echo "📦 Arquivo: $BACKUP_DIR/$BACKUP_FILE"
echo "💾 Tamanho: $BACKUP_SIZE"
echo ""
echo "🔄 Para restaurar em outro PC:"
echo "   1. Copie para pendrive"
echo "   2. No PC destino: ./restore.sh $BACKUP_DIR/$BACKUP_FILE"
echo ""

exit 0

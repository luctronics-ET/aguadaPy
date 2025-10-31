#!/bin/bash
set -e

echo "🚀 Iniciando Backend Aguada CMMS..."

# Aguarda PostgreSQL estar pronto
echo "⏳ Aguardando PostgreSQL..."
until pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER; do
  echo "PostgreSQL não está pronto - aguardando..."
  sleep 2
done

echo "✅ PostgreSQL pronto!"

# Inicializa banco de dados se necessário
if [ -d "/app/database" ]; then
    echo "📦 Verificando se banco de dados precisa ser inicializado..."
    
    # Verifica se o schema supervisorio já existe
    SCHEMA_EXISTS=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -tAc "SELECT 1 FROM information_schema.schemata WHERE schema_name='supervisorio'")
    
    if [ "$SCHEMA_EXISTS" != "1" ]; then
        echo "🚀 Inicializando banco de dados..."
        
        # Executa cada script SQL na ordem
        for script in schema.sql functions.sql triggers.sql seeds.sql; do
            if [ -f "/app/database/$script" ]; then
                echo "   Executando $script..."
                PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "/app/database/$script" || echo "⚠️ Erro ao executar $script (pode ser normal se já existe)"
            fi
        done
        
        echo "✅ Banco de dados inicializado!"
    else
        echo "ℹ️  Banco de dados já inicializado."
    fi
fi

echo "🎯 Iniciando aplicação FastAPI..."

# Executa o comando passado (uvicorn)
exec "$@"

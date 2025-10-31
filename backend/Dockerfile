FROM python:3.11-slim

WORKDIR /app

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements do backend
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código do backend
COPY backend/src/ ./src/
COPY backend/init_db.py .
COPY backend/docker-entrypoint.sh /docker-entrypoint.sh

# Copiar scripts SQL
COPY database/ ./database/

# Tornar entrypoint executável
RUN chmod +x /docker-entrypoint.sh

# Expor porta
EXPOSE 3000

# Comando de inicialização
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "3000", "--reload"]

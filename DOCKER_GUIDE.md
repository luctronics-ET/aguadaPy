# Guia Docker - Sistema Aguada CMMS/BMS

## 🐳 Visão Geral

Este sistema utiliza **Docker** e **Docker Compose** para facilitar:
- ✅ Deploy em PC isolado (sem internet)
- ✅ Transferência via pendrive
- ✅ Backup/restore completo
- ✅ Ambiente consistente entre desenvolvimento e produção

---

## 📦 Arquitetura de Containers

```
┌─────────────────────────────────────────────────┐
│                  DOCKER HOST                    │
│                                                 │
│  ┌──────────────┐  ┌──────────────┐            │
│  │  Frontend    │  │   Backend    │            │
│  │  (Nginx)     │  │  (Node.js)   │            │
│  │  Porta: 80   │  │  Porta: 3000 │            │
│  └──────┬───────┘  └──────┬───────┘            │
│         │                  │                     │
│         └─────────┬────────┘                     │
│                   │                              │
│         ┌─────────▼────────┐                     │
│         │   PostgreSQL     │                     │
│         │   Porta: 5432    │                     │
│         └──────────────────┘                     │
│                   │                              │
│         ┌─────────▼────────┐                     │
│         │  Volume Docker   │                     │
│         │  (persistência)  │                     │
│         └──────────────────┘                     │
└─────────────────────────────────────────────────┘
```

---

## 🚀 Instalação no PC de Destino

### 1. Instalar Docker (se não tiver)

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo apt install docker-compose

# Reinicie o terminal ou faça logout/login
```

### 2. Verificar Instalação

```bash
docker --version
docker-compose --version
```

---

## 📥 Deploy do Sistema (Via Pendrive)

### Passo 1: Preparar Pendrive (no PC de desenvolvimento)

```bash
# No PC atual (/opt/lampp/htdocs/aguadaPy)
./backup.sh /media/pendrive
```

Isso vai criar: `/media/pendrive/aguada_backup_YYYYMMDD_HHMMSS.tar.gz`

### Passo 2: Transferir para PC de Destino

1. Conecte o pendrive no PC de destino
2. Copie o arquivo `.tar.gz` para uma pasta (ex: `/home/usuario/aguada/`)

### Passo 3: Restaurar no PC de Destino

```bash
cd /home/usuario/aguada
./restore.sh aguada_backup_20251030_143000.tar.gz
```

✅ Pronto! Sistema rodando!

---

## 🔧 Comandos Úteis

### Gerenciar Sistema

```bash
# Iniciar sistema
./deploy.sh start

# Parar sistema
./deploy.sh stop

# Reiniciar sistema
./deploy.sh restart

# Ver logs em tempo real
./deploy.sh logs

# Ver status dos containers
./deploy.sh status
```

### Comandos Docker Diretos

```bash
# Ver containers rodando
docker ps

# Ver logs de um container específico
docker logs -f aguada_backend
docker logs -f aguada_postgres
docker logs -f aguada_frontend

# Acessar shell do container
docker exec -it aguada_backend sh
docker exec -it aguada_postgres psql -U aguada_user -d aguada_cmms

# Ver uso de recursos
docker stats
```

### Backup Manual do Banco

```bash
# Exportar dump SQL
docker exec aguada_postgres pg_dump -U aguada_user aguada_cmms > backup_manual.sql

# Importar dump SQL
docker exec -i aguada_postgres psql -U aguada_user aguada_cmms < backup_manual.sql
```

---

## 🌐 Configuração de Rede Local

### IPs Fixos (Recomendado)

Edite `/etc/docker/daemon.json`:

```json
{
  "bip": "172.17.0.1/16"
}
```

Reinicie Docker: `sudo systemctl restart docker`

### Acessar de Outros PCs na Rede

Se o PC está em `192.168.1.100`:

```
Dashboard:   http://192.168.1.100
API:         http://192.168.1.100:3000
PostgreSQL:  192.168.1.100:5432
```

**ESP32 deve configurar**: `const char* apiUrl = "http://192.168.1.100:3000/api/leituras/raw";`

---

## 🔒 Segurança

### Alterar Senhas Padrão

Edite `.env`:

```bash
# TROCAR ESTAS SENHAS!
POSTGRES_PASSWORD=sua_senha_forte_aqui
DB_PASSWORD=sua_senha_forte_aqui
JWT_SECRET=string_aleatoria_muito_longa_e_segura
```

Depois: `./deploy.sh restart`

### Firewall (Opcional)

```bash
# Permitir apenas rede local
sudo ufw allow from 192.168.1.0/24 to any port 80
sudo ufw allow from 192.168.1.0/24 to any port 3000
sudo ufw enable
```

---

## 💾 Backup Automático

### Cron Job Diário

```bash
# Editar crontab
crontab -e

# Adicionar linha (backup diário às 2h da manhã)
0 2 * * * /home/usuario/aguada/backup.sh /home/usuario/backups
```

### Limpar Backups Antigos (manter últimos 7)

```bash
find /home/usuario/backups -name "aguada_backup_*.tar.gz" -mtime +7 -delete
```

---

## 🐛 Troubleshooting

### Container não inicia

```bash
# Ver logs de erro
docker-compose -p aguada-cmms logs

# Reconstruir containers
./deploy.sh stop
docker-compose -p aguada-cmms build --no-cache
./deploy.sh start
```

### PostgreSQL não conecta

```bash
# Verificar se está rodando
docker exec aguada_postgres pg_isready -U aguada_user

# Acessar diretamente
docker exec -it aguada_postgres psql -U aguada_user -d aguada_cmms

# Ver logs
docker logs aguada_postgres
```

### Porta já em uso

```bash
# Descobrir processo usando porta 80
sudo lsof -i :80

# Mudar porta no docker-compose.yml
# frontend:
#   ports:
#     - "8080:80"  # Usar porta 8080 no host
```

### Espaço em disco

```bash
# Limpar containers e imagens antigas
docker system prune -a

# Ver uso de disco
docker system df
```

---

## 📊 Monitoramento

### Ver uso de recursos

```bash
docker stats aguada_postgres aguada_backend aguada_frontend
```

### Logs estruturados

Os logs ficam em `./logs/`:
- `backend.log` - Logs da API
- `postgres.log` - Logs do banco
- `nginx.log` - Logs do frontend

---

## 🔄 Atualização do Sistema

### Atualizar código (sem perder dados)

```bash
# 1. Fazer backup
./backup.sh

# 2. Atualizar código (git pull ou copiar novos arquivos)
git pull

# 3. Reconstruir containers
docker-compose -p aguada-cmms build

# 4. Reiniciar
./deploy.sh restart
```

---

## 📱 Conectar ESP32

No firmware do ESP32, configure:

```cpp
// Trocar pelo IP do PC onde roda o Docker
const char* apiUrl = "http://192.168.1.100:3000/api/leituras/raw";
```

Teste conectividade:

```bash
# No ESP32, faça ping
ping 192.168.1.100

# No PC, veja se ESP32 está conectando
docker logs -f aguada_backend | grep "POST /api/leituras"
```

---

## 📞 Suporte

Para mais informações, consulte:
- `README.md` - Documentação geral do projeto
- `TODO.md` - Lista de tarefas
- `ESTRATEGIA_IOT.md` - Estratégia de hardware

---

**Última atualização**: 2025-10-30

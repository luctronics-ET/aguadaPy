## ✅ Extensões Instaladas

As seguintes extensões foram instaladas para facilitar o desenvolvimento:

### 🐍 Python
- **ms-python.python** - Suporte completo para Python
- **ms-python.vscode-pylance** - IntelliSense avançado para Python
- ✅ Configurado para usar formatação automática (Black)
- ✅ Linting com Flake8

### 🐳 Docker
- **ms-azuretools.vscode-docker** - Gerenciamento de containers
- ✅ Visualizar containers rodando
- ✅ Logs integrados
- ✅ Attach to container

### 🗄️ Banco de Dados
- **mtxr.sqltools** - Cliente SQL universal
- **mtxr.sqltools-driver-pg** - Driver PostgreSQL
- ✅ Conexão pré-configurada para aguadaPy
- ✅ Queries prontas em `queries_uteis.sql`

### 📡 API Testing
- **humao.rest-client** - Testar APIs HTTP
- ✅ Arquivo `test_api.http` com 16 testes prontos
- ✅ Use `Ctrl+Alt+R` para executar requests

### 🔧 IoT & Firmware
- **platformio.platformio-ide** - Desenvolvimento ESP32/Arduino
- ✅ Suporte para compilar firmwares
- ✅ Upload e monitor serial integrado

### 📝 Utilitários
- **redhat.vscode-yaml** - Suporte para YAML
- ✅ Validação de docker-compose.yml
- ✅ Auto-complete

---

## 🚀 Como Usar

### 1. Testar Backend API

Abra `test_api.http` e clique em **"Send Request"** acima de cada requisição:

```http
### Health Check
GET http://localhost:3000/health
```

**Atalho**: `Ctrl+Alt+R` com cursor na linha

### 2. Conectar ao PostgreSQL

1. Abra paleta de comandos (`Ctrl+Shift+P`)
2. Digite: `SQLTools: Connect`
3. Selecione: **aguadaPy PostgreSQL**
4. Execute queries do arquivo `queries_uteis.sql`

### 3. Gerenciar Docker

- **View → Docker** (ou `Ctrl+Shift+D`)
- Ver containers, imagens, volumes
- Click direito → View Logs
- Click direito → Attach Shell

### 4. Desenvolver Python

Formatação automática ao salvar:
- Black formatter
- Organize imports
- Remove imports não utilizados

### 5. Compilar Firmware ESP32

```bash
# Com PlatformIO instalado
cd firmware2/gateway_wifi
pio run  # ou use o botão na barra inferior
```

---

## 📁 Arquivos Criados

- `.vscode/settings.json` - Configurações do projeto
- `test_api.http` - 16 testes de API prontos
- `queries_uteis.sql` - 10 queries úteis para PostgreSQL

---

## 🔑 Atalhos Úteis

| Ação | Atalho |
|------|--------|
| Executar HTTP Request | `Ctrl+Alt+R` |
| Abrir Command Palette | `Ctrl+Shift+P` |
| Terminal Integrado | `` Ctrl+` `` |
| Explorador de Arquivos | `Ctrl+Shift+E` |
| Buscar em Arquivos | `Ctrl+Shift+F` |
| Debug | `F5` |
| Conectar SQLTools | `Ctrl+Shift+P` → "SQLTools: Connect" |

---

## 🎯 Próximos Passos

1. **Iniciar Docker:**
   ```bash
   ./deploy.sh start
   ```

2. **Testar API:**
   - Abrir `test_api.http`
   - Executar requests com `Ctrl+Alt+R`

3. **Conectar ao Banco:**
   - `Ctrl+Shift+P` → "SQLTools: Connect"
   - Executar queries de `queries_uteis.sql`

4. **Ver Logs:**
   - Docker extension → aguada_backend → View Logs

Tudo pronto! 🎉

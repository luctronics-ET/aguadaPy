# 🧪 Guia de Teste - Portal de Configuração

## 📋 Pré-requisitos

- ESP32-C3 Gateway programado e ligado
- Smartphone ou computador com WiFi
- Rede WiFi doméstica disponível (para configurar)
- Backend Aguada rodando (XAMPP/LAMPP)

## 🚀 Procedimento de Teste

### 1️⃣ Primeiro Boot (Modo SETUP)

**O que deve acontecer:**

```
✅ Gateway inicia em MODO SETUP (sem configuração salva)
✅ Cria rede WiFi: AGUADA-SETUP
✅ Senha: aguada2025
✅ IP do gateway: 192.168.4.1
✅ Servidor web rodando na porta 80
✅ DNS server rodando na porta 53 (captive portal)
```

**Logs esperados no monitor serial:**

```
I (318) GATEWAY: 🌊 CMASM - Aguada V2.5 - Gateway
W (347) CONFIG_MGR: ⚠️  Gateway não configurado
W (348) GATEWAY: 🔧 Gateway não configurado - entrando em MODO SETUP
I (355) GATEWAY: 🔧 Iniciando WiFi em MODO SETUP (AP)...
I (524) GATEWAY: ✅ WiFi AP: AGUADA-SETUP (Senha: aguada2025)
I (547) WEB_SERVER: ✅ Servidor web iniciado
I (561) DNS_SERVER: ✅ DNS server iniciado na porta 53
I (612) GATEWAY: 📱 MODO SETUP ATIVO
```

---

### 2️⃣ Conectar ao Gateway

**No smartphone/computador:**

1. Abra as configurações de WiFi
2. Procure a rede: **AGUADA-SETUP**
3. Conecte usando a senha: **aguada2025**
4. Aguarde a conexão ser estabelecida

**Comportamento esperado:**

- ✅ Conexão bem-sucedida
- ✅ IP atribuído na faixa 192.168.4.x
- ⚠️ **Pode aparecer "Sem internet"** (normal - é uma rede local)

**Teste do captive portal:**

- **Android**: Deve abrir automaticamente o portal de configuração
- **iOS**: Pode aparecer popup "Fazer login na rede"
- **Windows/Linux**: Pode não abrir automaticamente (normal)

**Se não abrir automaticamente:**

- Abra o navegador manualmente
- Acesse: `http://192.168.4.1`
- Ou tente: `http://aguada-setup.local` (se mDNS funcionar)

---

### 3️⃣ Testar WiFi Scan

**Na página web:**

1. Clique no botão **"Buscar Redes"**
2. Aguarde 3-5 segundos

**Resultado esperado:**

```json
✅ Lista de redes WiFi aparece
✅ Mostra SSID, sinal (RSSI), canal e segurança
✅ Sua rede doméstica aparece na lista
```

**Exemplo da resposta JSON:**

```json
{
  "networks": [
    {
      "ssid": "MEU_WIFI_CASA",
      "rssi": -45,
      "channel": 6,
      "security": "WPA2"
    },
    {
      "ssid": "VIZINHO_WIFI",
      "rssi": -72,
      "channel": 11,
      "security": "WPA2"
    }
  ]
}
```

**Se falhar:**

- Verifique logs: `idf.py -p /dev/ttyACM0 monitor`
- Deve mostrar: `I (xxx) WEB_SERVER: 📡 Iniciando WiFi scan...`
- Deve mostrar: `I (xxx) WEB_SERVER:    Encontradas X redes`

---

### 4️⃣ Configurar WiFi

**Passo 1 - Selecionar rede:**

- Clique em uma rede da lista **OU**
- Digite manualmente o nome da rede no campo "SSID"
- Digite a senha da rede WiFi
- Clique em **"Próximo"**

**Validações:**

- ✅ SSID não pode estar vazio
- ✅ Senha não pode estar vazia (exceto redes abertas)

---

### 5️⃣ Configurar Backend

**Passo 2 - Servidor backend:**

**Opção A: Discovery automático (se estiver na mesma rede)**

- Clique em **"Descobrir Servidor"**
- Aguarde detecção automática
- IP e porta devem preencher automaticamente

**Opção B: Manual**

- Digite o IP do servidor: `192.168.0.101` (ou IP do seu XAMPP)
- Porta: `80` (padrão HTTP)
- Path: `/aguada/api_gateway.php` (já preenchido)

**URL final esperada:**

```
http://192.168.0.101:80/aguada/api_gateway.php
```

**Clique em "Próximo"**

---

### 6️⃣ Confirmar e Salvar

**Passo 3 - Revisão:**

Verifique os dados:

```
📡 WiFi: MEU_WIFI_CASA
🔐 Senha: ********

🌐 Backend: http://192.168.0.101:80/aguada/api_gateway.php
```

**Ações:**

- Clique em **"Salvar e Reiniciar"** para confirmar
- **OU** clique em **"Voltar"** para corrigir

---

### 7️⃣ Reinício (Modo NORMAL)

**O que acontece:**

1. Gateway salva configuração na NVS (flash)
2. Gateway reinicia automaticamente
3. Inicia em **MODO NORMAL** (APSTA)

**Logs esperados:**

```
I (351) CONFIG_MGR: 📥 Configuração carregada:
I (351) CONFIG_MGR:    WiFi: MEU_WIFI_CASA
I (354) CONFIG_MGR:    Backend: http://192.168.0.101:80/aguada/api_gateway.php
I (362) GATEWAY: ✅ Configuração encontrada - MODO NORMAL
I (381) GATEWAY: 📡 Iniciando WiFi em MODO NORMAL (APSTA)...
I (554) GATEWAY: ✅ WiFi AP: AGUADA-SETUP (Canal 11)
I (560) GATEWAY: 🔄 Conectando a: MEU_WIFI_CASA
```

**Duas opções:**

**A) Conectou com sucesso:**

```
I (15000) WIFI_EVENT: WiFi conectado!
I (15010) IP_EVENT: IP: 192.168.0.XXX
I (15566) GATEWAY: ✅ ESP-NOW inicializado
I (15575) GATEWAY: 📊 Status Gateway:
I (15579) GATEWAY:    WiFi: ON
I (15584) GATEWAY:    Backend: ONLINE
```

**B) Falhou ao conectar (senha errada/rede não encontrada):**

```
W (3398) GATEWAY: WiFi STA desconectado, reconectando...
W (6232) GATEWAY: WiFi STA desconectado, reconectando...
W (15566) GATEWAY: ⚠️  Falha ao conectar - apenas AP local
I (15575) GATEWAY:    WiFi: OFF
I (15584) GATEWAY:    Backend: OFFLINE
```

---

### 8️⃣ Teste de Comunicação

**Se conectou ao WiFi:**

1. Gateway deve receber pacotes ESP-NOW dos sensores
2. Deve enviar dados ao backend via HTTP POST

**Logs esperados:**

```
I (30559) GATEWAY: 📥 RX: MAC=DC:06:75:67:6A:CC, seq=2529, value_id=1, dist=174 cm, RSSI=-90 dBm
I (30600) GATEWAY: 📤 Enviando ao backend...
I (30800) GATEWAY: ✅ Backend respondeu: {"success":true,"message":"Leitura salva"}
I (30805) GATEWAY:    Packets RX: 1
I (30810) GATEWAY:    Packets TX: 1
```

**Verificar no dashboard:**

- Acesse: `http://192.168.0.101/aguada/dashboard.php`
- Verifique se aparecem leituras novas dos sensores

---

## 🔧 Troubleshooting

### Problema: WiFi scan não retorna redes

**Causa:** ESP32 em modo AP-only não consegue fazer scan

**Solução:** ✅ CORRIGIDO - agora usa APSTA no modo setup

**Teste:**

```bash
cd /opt/lampp/htdocs/aguada/firmware/gateway_wifi
source ~/esp/v5.5.1/esp-idf/export.sh
idf.py -p /dev/ttyACM0 monitor
```

Procure por:

```
I (xxx) WEB_SERVER: 📡 Iniciando WiFi scan...
I (xxx) WEB_SERVER:    Encontradas X redes
```

---

### Problema: Captive portal não abre automaticamente

**Causas possíveis:**

1. DNS server não está rodando
2. Dispositivo não faz DNS lookup
3. Sistema operacional não detecta portal

**Verificações:**

```bash
# No monitor serial, procure por:
I (561) DNS_SERVER: ✅ DNS server iniciado na porta 53
```

**Soluções:**

- **Android**: Deve funcionar automaticamente
- **iOS**: Deve aparecer popup
- **Windows/Linux**: Abra navegador manualmente → `http://192.168.4.1`

**Teste manual do DNS:**

```bash
# No seu computador conectado ao AGUADA-SETUP:
nslookup www.google.com 192.168.4.1
# Deve retornar: 192.168.4.1
```

---

### Problema: Configuração salva mas não conecta

**Causa 1: Senha incorreta**

- Gateway tenta conectar mas falha repetidamente
- Logs: `W (xxx) GATEWAY: WiFi STA desconectado, reconectando...`

**Solução:** Resetar e reconfigurar

```bash
cd /opt/lampp/htdocs/aguada/firmware/gateway_wifi
source ~/esp/v5.5.1/esp-idf/export.sh
idf.py -p /dev/ttyACM0 erase-flash  # Apaga NVS
idf.py -p /dev/ttyACM0 flash         # Regrava firmware
```

**Causa 2: Rede fora de alcance**

- Gateway não consegue ver a rede
- Aproxime o gateway do roteador

**Causa 3: Configuração de backend incorreta**

- WiFi conecta mas backend offline
- Verifique IP e porta do servidor

---

### Problema: Não envia dados ao backend

**Verificações:**

1. **WiFi conectado?**

```
I (xxx) GATEWAY:    WiFi: ON  <-- deve estar ON
```

2. **Backend acessível?**

```bash
# Do gateway, testa conexão:
curl -X POST http://192.168.0.101/aguada/api_gateway.php \
  -H "Content-Type: application/json" \
  -d '{"test":true}'
```

3. **Logs do gateway:**

```
I (xxx) GATEWAY: 📤 Enviando ao backend...
E (xxx) HTTP_CLIENT: Failed to connect  <-- erro de conexão
```

**Soluções:**

- Verifique firewall no servidor
- Verifique IP do backend está correto
- Teste `ping 192.168.0.101` do seu computador

---

## 📊 Checklist de Testes

### Modo SETUP

- [ ] Gateway cria rede AGUADA-SETUP
- [ ] Consigo conectar com senha `aguada2025`
- [ ] Página abre em `http://192.168.4.1`
- [ ] Captive portal abre automaticamente (Android/iOS)
- [ ] WiFi scan retorna lista de redes
- [ ] Consigo selecionar uma rede da lista
- [ ] Consigo digitar SSID manualmente
- [ ] Discovery de servidor funciona (se na mesma rede)
- [ ] Validação de campos funciona
- [ ] Botão "Salvar e Reiniciar" funciona

### Modo NORMAL

- [ ] Gateway reinicia após salvar
- [ ] Conecta ao WiFi configurado
- [ ] Obtém IP do roteador
- [ ] ESP-NOW inicializa
- [ ] Recebe pacotes dos sensores
- [ ] Envia dados ao backend via HTTP
- [ ] Backend salva no banco de dados
- [ ] Dashboard mostra leituras novas

### Reset e Reconfiguração

- [ ] `idf.py erase-flash` apaga configuração
- [ ] Volta ao modo SETUP após erase-flash
- [ ] Posso configurar novamente

---

## 📝 Notas Importantes

1. **NVS persiste após reset de software** - Só apaga com `erase-flash` ou `erase-nvs`
2. **AP sempre ativo** - Mesmo em modo normal, AGUADA-SETUP continua disponível
3. **Timeout de conexão** - Gateway aguarda 15 segundos para conectar ao WiFi
4. **Reconexão automática** - Se WiFi cair, gateway tenta reconectar automaticamente
5. **ESP-NOW no mesmo canal do AP** - Canal 11 fixo para compatibilidade

---

## 🐛 Logs de Debug

**Ativar logs verbose:**

```c
// Em main/main.c, adicione:
esp_log_level_set("*", ESP_LOG_VERBOSE);
```

**Monitorar em tempo real:**

```bash
cd /opt/lampp/htdocs/aguada/firmware/gateway_wifi
source ~/esp/v5.5.1/esp-idf/export.sh
idf.py -p /dev/ttyACM0 monitor
```

**Salvar logs em arquivo:**

```bash
idf.py -p /dev/ttyACM0 monitor 2>&1 | tee gateway_logs.txt
```

---

## 📬 Reportar Problemas

Ao reportar problemas, inclua:

1. **Logs completos** do monitor serial (desde o boot)
2. **Descrição** do comportamento esperado vs observado
3. **Screenshots** da interface web (se aplicável)
4. **Ambiente**: Sistema operacional, dispositivo usado

---

**Última atualização:** 28/10/2025
**Versão do firmware:** v2.5
**Autor:** Sistema Aguada - CMASM

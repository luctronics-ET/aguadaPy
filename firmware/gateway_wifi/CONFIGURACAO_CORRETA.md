# ⚠️ CONFIGURAÇÃO CORRETA DO GATEWAY

## 🎯 ATENÇÃO: IP CORRETO DO SERVIDOR

Seu servidor XAMPP está em: **`192.168.1.101`**

**NÃO use:** ~~`192.168.0.101`~~ ❌

---

## 📝 Passo a Passo - CONFIGURAÇÃO CORRETA

### 1️⃣ Conectar ao WiFi do Gateway

- **SSID:** `AGUADA-SETUP`
- **Senha:** `aguada2025`

### 2️⃣ Acessar Portal Web

- Abra navegador
- Acesse: `http://192.168.4.1`

### 3️⃣ Configurar WiFi (Passo 1)

- Clique em **"Buscar Redes"**
- Selecione: **`TP-LINK_BE3344`**
- Digite a senha do WiFi
- Clique em **"Próximo"**

### 4️⃣ Configurar Backend (Passo 2) - **MUITO IMPORTANTE!**

```
┌────────────────────────────────────────┐
│  URL do Servidor                       │
│  ┌──────────────────────────────────┐  │
│  │ 192.168.1.101/aguada/api_gateway.php  │  ← ✅ USE ESTE IP!
│  └──────────────────────────────────┘  │
│                                        │
│  Porta                                 │
│  ┌──────────────────────────────────┐  │
│  │ 80                               │  │
│  └──────────────────────────────────┘  │
│                                        │
│  [ Próximo ]                          │
└────────────────────────────────────────┘
```

**CUIDADO:**
- ✅ **CORRETO:** `192.168.1.101/aguada/api_gateway.php`
- ❌ **ERRADO:** ~~`192.168.0.101/aguada/api_gateway.php`~~

### 5️⃣ Confirmar (Passo 3)

Verifique que mostra:

```
📡 WiFi: TP-LINK_BE3344
🔐 Senha: ********

🌐 Backend: http://192.168.1.101/aguada/api_gateway.php
                    ^^^^^^^^^^^^ 
                    VERIFIQUE ESTE IP!
```

Se estiver **`192.168.1.101`** ✅ → Clique em **"Salvar e Reiniciar"**

Se estiver **`192.168.0.101`** ❌ → Clique em **"Voltar"** e corrija!

---

## 🔍 Como Verificar se Funcionou

Após salvar e reiniciar:

```bash
cd /opt/lampp/htdocs/aguada/firmware/gateway_wifi
idf.py -p /dev/ttyACM0 monitor
```

### ✅ Logs de SUCESSO (procure por isto):

```
I (xxx) CONFIG_MGR:    Backend: http://192.168.1.101/aguada/api_gateway.php:80
                                      ^^^^^^^^^^^^ CORRETO!

I (xxx) GATEWAY: ✅ WiFi conectado! IP: 192.168.1.100
I (xxx) GATEWAY: 📡 URL: http://192.168.1.101/aguada/api_gateway.php
                               ^^^^^^^^^^^^ CORRETO!
I (xxx) GATEWAY: ✅ Backend: OK (200)  ← ESTE É O MAIS IMPORTANTE!
I (xxx) GATEWAY:    Packets TX: 1     ← ENVIOU DADOS!
```

### ❌ Logs de ERRO (se isto aparecer, IP está ERRADO):

```
I (xxx) CONFIG_MGR:    Backend: http://192.168.0.101/aguada/api_gateway.php:80
                                      ^^^^^^^^^^^^ ERRADO!

E (xxx) esp-tls: [sock=54] select() timeout
E (xxx) HTTP_CLIENT: Connection failed, sock < 0
W (xxx) GATEWAY: ❌ HTTP falhou: ESP_ERR_HTTP_CONNECT
```

---

## 🔄 Se Errar o IP Novamente

```bash
cd /opt/lampp/htdocs/aguada/firmware/gateway_wifi
idf.py -p /dev/ttyACM0 erase-flash    # Apagar configuração errada
idf.py -p /dev/ttyACM0 flash           # Regravar firmware
# Depois configure novamente com IP CORRETO!
```

---

## 📊 Verificar Dados no Dashboard

Depois que aparecer `✅ Backend: OK (200)` nos logs:

1. Abra navegador
2. Acesse: `http://192.168.1.101/aguada/leituras.php`
3. Deve aparecer leituras NOVAS com data/hora ATUAL

---

## 🆘 Troubleshooting Rápido

| Problema | Causa | Solução |
|----------|-------|---------|
| Backend OFFLINE | IP errado (`192.168.0.101`) | Use `192.168.1.101` |
| Connection timeout | Servidor não alcançável | Verifique XAMPP rodando |
| Não aparece no dashboard | Gateway não enviando | Verifique logs com `idf.py monitor` |
| WiFi não conecta | Senha errada | Reconfigurar WiFi |

---

## ✅ Checklist Final

Antes de salvar a configuração, confirme:

- [ ] IP do servidor: **`192.168.1.101`** (não `192.168.0.101`)
- [ ] Path: `/aguada/api_gateway.php`
- [ ] Porta: `80`
- [ ] URL completa: `http://192.168.1.101/aguada/api_gateway.php`

---

**Agora vá configurar com o IP CORRETO!** 🚀

Depois volte aqui e me diga se apareceu `✅ Backend: OK (200)` nos logs!

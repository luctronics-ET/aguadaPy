# NODE-02 - Guia de Calibração

## 📐 Medidas Físicas Necessárias

Antes de instalar o sensor, meça:

1. **ALTURA_SENSOR_CM**: Distância do sensor HC-SR04 até o fundo do tanque
   - Exemplo: Se o sensor está a 250 cm do fundo → `#define ALTURA_SENSOR_CM 250`

2. **ALTURA_TANQUE_CM**: Altura útil do tanque (capacidade total)
   - Exemplo: Tanque de 2 metros de altura → `#define ALTURA_TANQUE_CM 200`

3. **OFFSET_CM**: Ajuste fino após comparar com régua física
   - Padrão: `0`
   - Se sensor marca 95 cm mas régua mostra 100 cm → `#define OFFSET_CM 5`

## 🔧 Configuração no Código

Edite `src/main.cpp` nas linhas 23-25:

```cpp
// Calibração Física (AJUSTAR CONFORME SEU TANQUE!)
#define ALTURA_SENSOR_CM 250    // Distância do sensor ao fundo
#define ALTURA_TANQUE_CM 200    // Altura útil do tanque
#define OFFSET_CM 0             // Offset de calibração
```

## 📊 Exemplo de Cálculo

### Cenário Real:
- Sensor instalado no topo do tanque: **250 cm** do fundo
- Tanque útil: **200 cm** de altura
- Sensor mede: **5 cm** de distância até a água

### Cálculo do Nível:
```
Nível = ALTURA_SENSOR - Distância + OFFSET
Nível = 250 cm - 5 cm + 0 cm
Nível = 245 cm
```

**Mas...** o tanque só tem 200 cm úteis!  
O código limita automaticamente: **Nível = 200 cm (100%)**

### Outro Exemplo:
- Sensor mede: **100 cm**
- Nível = 250 - 100 + 0 = **150 cm**
- Percentual = (150 / 200) × 100 = **75%** ✅

## 🎯 Processo de Calibração

### 1. Instalação Inicial
```bash
# Compilar com valores padrão
platformio run -t upload

# Monitorar serial
platformio device monitor -b 9600
```

### 2. Comparar com Medição Manual
- Meça o nível real com régua física
- Compare com valor mostrado na serial
- Anote a diferença

### 3. Ajustar OFFSET
Se houver diferença consistente:
```cpp
// Sensor mostra 95 cm, mas real é 100 cm
#define OFFSET_CM 5  // Adiciona 5 cm

// Sensor mostra 105 cm, mas real é 100 cm
#define OFFSET_CM -5  // Subtrai 5 cm
```

### 4. Recompilar e Testar
```bash
platformio run -t upload
```

## 📱 Dados Enviados

O NODE-02 envia 3 valores para o backend:

```json
{
  "mac_address": "AA:BB:CC:DD:EE:02",
  "readings": [{
    "sensor_id": 1,
    "distance_cm": 5,      // ← Distância bruta do sensor
    "nivel_cm": 200,       // ← Nível calculado
    "percentual": 100      // ← Percentual do tanque
  }],
  "sequence": 0,
  "rssi": -35
}
```

## 🔍 Solução de Problemas

### Sensor Sempre Marca 100%
**Causa**: `ALTURA_SENSOR_CM` muito alto  
**Solução**: Meça novamente a distância sensor→fundo

### Sensor Sempre Marca 0%
**Causa**: `ALTURA_SENSOR_CM` muito baixo  
**Solução**: Verifique se sensor está realmente no topo

### Leitura Instável (varia muito)
**Causa**: Superfície da água agitada ou obstáculos  
**Solução**: 
- Aguarde água estabilizar
- Instale anteparo para reduzir ondulação
- Aumente número de amostras (de 3 para 5)

### Diferença de ±5cm Comparado com Régua
**Causa**: Variação normal do HC-SR04 ou posição do sensor  
**Solução**: Ajuste `OFFSET_CM`

## 📝 Histórico de Calibrações

Mantenha registro de ajustes:

| Data | Offset Anterior | Offset Novo | Observações |
|------|----------------|-------------|-------------|
| 30/10/2025 | 0 | 0 | Instalação inicial |
| | | | |

## ⚙️ Configurações Avançadas

### Alterar Intervalo de Leitura
```cpp
#define INTERVAL_MS 30000  // 30 segundos (padrão)
#define INTERVAL_MS 60000  // 1 minuto (economizar energia)
#define INTERVAL_MS 10000  // 10 segundos (debug)
```

### Alterar Número de Amostras
```cpp
// Em lerDistancia(), linha ~66:
const int NUM_AMOSTRAS = 3;  // Padrão
const int NUM_AMOSTRAS = 5;  // Mais estável
const int NUM_AMOSTRAS = 1;  // Mais rápido (debug)
```

### Timeout do Sensor
```cpp
#define TIMEOUT_US 30000   // 30ms (padrão) = ~5m máximo
#define TIMEOUT_US 50000   // 50ms = ~8.5m para tanques grandes
```

## ✅ Checklist Final

Antes de fechar o gabinete:

- [ ] `ALTURA_SENSOR_CM` medido e configurado
- [ ] `ALTURA_TANQUE_CM` medido e configurado
- [ ] Teste com água em níveis diferentes (vazio, 50%, cheio)
- [ ] Comparação com régua física (erro < 5%)
- [ ] `OFFSET_CM` ajustado se necessário
- [ ] Cabo Ethernet conectado firmemente
- [ ] LED piscando a cada 30s (sinal de vida)
- [ ] Dados chegando no dashboard
- [ ] Registro de calibração preenchido

## 🎓 Fórmula Matemática

```
Nível Real (cm) = ALTURA_SENSOR - Distância Medida + OFFSET
Percentual (%) = (Nível Real / ALTURA_TANQUE) × 100
```

Limitadores:
```
Se Nível < 0          → Nível = 0
Se Nível > ALTURA_TANQUE → Nível = ALTURA_TANQUE
```

---

**Documentação Gerada**: 30/10/2025  
**Versão Firmware**: 3.0 (Produção)  
**Última Atualização**: NODE-02 Finalizado

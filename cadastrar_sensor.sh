#!/bin/bash

# ============================================
# Script para Cadastrar Novos Sensores
# ============================================

echo "📝 CADASTRO DE SENSOR - AGUADAPY"
echo "================================="
echo ""

# Verificar argumentos
if [ "$#" -lt 3 ]; then
    echo "Uso: $0 <MAC_ADDRESS> <VALUE_ID> <NOME_SENSOR> [ELEMENTO_ID]"
    echo ""
    echo "Exemplos:"
    echo "  $0 'AA:BB:CC:DD:EE:FF' 1 'SEN_NODE04_NIVEL' 27"
    echo "  $0 'DC:06:75:67:6A:CC' 1 'SEN_NODE01_NIVEL' 27"
    echo ""
    echo "Sensores já cadastrados:"
    docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -c "SELECT sensor_id, elemento_id, meta->>'mac_address' as mac FROM supervisorio.sensores;"
    exit 1
fi

MAC_ADDRESS="$1"
VALUE_ID="$2"
SENSOR_ID="$3"
ELEMENTO_ID="${4:-27}"  # Default: 27 (RES_CONS)

echo "Cadastrando sensor:"
echo "  MAC Address: $MAC_ADDRESS"
echo "  Value ID: $VALUE_ID"
echo "  Sensor ID: $SENSOR_ID"
echo "  Elemento ID: $ELEMENTO_ID"
echo ""

# Verificar se sensor já existe
existing=$(docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -t -c "SELECT sensor_id FROM supervisorio.sensores WHERE sensor_id = '$SENSOR_ID' OR meta->>'mac_address' = '$MAC_ADDRESS';" 2>/dev/null | tr -d ' ')

if [ ! -z "$existing" ]; then
    echo "⚠️  Sensor já existe: $existing"
    echo ""
    read -p "Deseja atualizar? (s/n): " resposta
    if [ "$resposta" != "s" ]; then
        echo "Cancelado."
        exit 0
    fi
    
    # Atualizar sensor existente
    docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -c "
        UPDATE supervisorio.sensores 
        SET meta = jsonb_set(
            COALESCE(meta, '{}'::jsonb), 
            '{mac_address}', 
            '\"$MAC_ADDRESS\"'
        ),
        meta = jsonb_set(
            meta, 
            '{value_id}', 
            '$VALUE_ID'
        )
        WHERE sensor_id = '$existing';
    "
    echo "✅ Sensor atualizado!"
else
    # Inserir novo sensor
    docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -c "
        INSERT INTO supervisorio.sensores (
            sensor_id, 
            elemento_id, 
            tipo, 
            modelo, 
            unidade, 
            precisao,
            range_min,
            range_max,
            freq_padrao_s,
            estado_operacional,
            meta
        ) VALUES (
            '$SENSOR_ID',
            $ELEMENTO_ID,
            'NIVEL',
            'HC-SR04',
            'cm',
            '±0.3cm',
            2.0,
            400.0,
            30,
            'ativo',
            jsonb_build_object(
                'mac_address', '$MAC_ADDRESS',
                'value_id', $VALUE_ID,
                'node', UPPER(SUBSTRING('$SENSOR_ID' FROM 'NODE[0-9]+'))
            )
        );
    "
    echo "✅ Sensor cadastrado com sucesso!"
fi

echo ""
echo "Sensores cadastrados:"
docker exec aguada_postgres psql -U aguada_user -d aguada_cmms -c "
    SELECT 
        sensor_id, 
        elemento_id, 
        tipo,
        estado_operacional,
        meta->>'mac_address' as mac_address,
        meta->>'value_id' as value_id
    FROM supervisorio.sensores
    ORDER BY sensor_id;
"

echo ""
echo "✅ Pronto! Agora o gateway pode enviar dados deste sensor."

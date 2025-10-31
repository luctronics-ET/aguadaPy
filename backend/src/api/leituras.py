"""
Endpoints para leituras de sensores
Compatível com sensor_packet_t do ESP32/Arduino
"""

from fastapi import APIRouter, HTTPException, status, Request
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
import logging

from ..database import get_cursor

logger = logging.getLogger(__name__)

router = APIRouter()

# ==================== MODELOS ====================

class SensorPacket(BaseModel):
    """
    Estrutura compatível com sensor_packet_t do firmware
    
    typedef struct {
        uint8_t  mac[6];       // MAC address
        uint8_t  value_id;     // ID do sensor
        uint16_t distance_cm;  // Distância em cm
        uint16_t sequence;     // Número sequencial
        int8_t   rssi;         // RSSI
        uint8_t  reserved;     // Reservado
    } sensor_packet_t;
    """
    mac: str = Field(..., description="MAC address (formato: AA:BB:CC:DD:EE:FF)")
    value_id: int = Field(..., ge=1, le=255, description="ID do sensor (1-255)")
    distance_cm: int = Field(..., ge=0, le=65535, description="Distância em cm")
    sequence: int = Field(default=0, ge=0, le=65535, description="Número sequencial")
    rssi: int = Field(default=0, ge=-127, le=127, description="RSSI em dBm")

class LeituraRaw(BaseModel):
    """Modelo para inserção de leitura raw"""
    sensor_id: int
    valor: float
    rssi: Optional[int] = None
    mac_address: Optional[str] = None
    sequence: Optional[int] = None

# ==================== ENDPOINTS ====================

@router.post("/raw", status_code=status.HTTP_201_CREATED)
async def receber_leitura_raw(request: Request):
    """
    Endpoint principal para ESP32/Arduino Gateway
    Compatível com api_gateway_v2.php do sistema original
    
    Aceita JSON ou form-data
    """
    try:
        # Tentar ler como JSON
        try:
            data = await request.json()
        except:
            # Fallback para form-data
            form = await request.form()
            data = dict(form)
        
        logger.info(f"📥 Leitura recebida: {data}")
        
        # Extrair campos (compatibilidade com ambos formatos)
        mac = data.get('mac') or data.get('mac_address')
        
        # Suporta formato com array "readings" do gateway
        if 'readings' in data and isinstance(data['readings'], list) and len(data['readings']) > 0:
            reading = data['readings'][0]
            value_id = int(reading.get('sensor_id', 0))
            distance_cm = int(reading.get('distance_cm', 0))
        else:
            value_id = int(data.get('value_id') or data.get('sensor_id', 0))
            distance_cm = int(data.get('distance_cm') or data.get('valor', 0))
            
        sequence = int(data.get('sequence', 0))
        rssi = int(data.get('rssi', 0))
        
        # Validar dados mínimos
        if not mac or value_id is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Campos obrigatórios: mac, value_id"
            )
        
        # Mapear value_id para sensor_id (baseado no MAC e value_id)
        # value_id=1 = sensor de nível principal
        # MAC identifica o dispositivo/localização
        with get_cursor() as cursor:
            # Buscar sensor pela combinação de MAC no metadata JSON
            cursor.execute("""
                SELECT sensor_id, elemento_id, tipo
                FROM supervisorio.sensores
                WHERE meta->>'mac_address' = %s
                   OR sensor_id = CONCAT('SEN_VAL_', %s::text)
                LIMIT 1
            """, (mac, value_id))
            
            sensor = cursor.fetchone()
            
            if not sensor:
                # Criar sensor temporário se não existir
                logger.warning(f"⚠️  Sensor mac={mac} value_id={value_id} não cadastrado! Usando senssor genérico.")
                # Usar um sensor genérico ou criar dinamicamente
                sensor_id = f"SEN_VAL_{value_id}"
                # Por enquanto, vamos retornar erro para forçar cadastro
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Sensor com MAC={mac} e value_id={value_id} não encontrado. Cadastre o sensor primeiro."
                )
            
            sensor_id = sensor['sensor_id']
            elemento_id = sensor['elemento_id']
            
            # Inserir leitura raw (tabela usa estrutura diferente - sem rssi, mac_address, sequence)
            cursor.execute("""
                INSERT INTO supervisorio.leituras_raw 
                (sensor_id, elemento_id, variavel, valor, unidade, fonte, datetime, observacao)
                VALUES (%s, %s, %s, %s, %s, %s, NOW(), %s)
                RETURNING leitura_id, datetime
            """, (
                sensor_id, 
                elemento_id,
                'nivel',  # variavel
                distance_cm,  # valor
                'cm',  # unidade
                'esp32_gateway',  # fonte
                f"MAC: {mac}, RSSI: {rssi}dBm, Seq: {sequence}"  # observacao
            ))
            
            result = cursor.fetchone()
            
            logger.info(f"✅ Leitura inserida: ID={result['leitura_id']}, "
                       f"sensor_id={sensor_id}, value_id={value_id}, "
                       f"valor={distance_cm}cm")
        
        return {
            "status": "success",
            "message": "Leitura recebida com sucesso",
            "leitura_id": result['leitura_id'],
            "sensor_id": sensor_id,
            "value_id": value_id,
            "datetime": result['datetime'].isoformat() if result['datetime'] else None
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Erro ao processar leitura: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro ao processar leitura: {str(e)}"
        )

@router.post("/packet", status_code=status.HTTP_201_CREATED)
async def receber_sensor_packet(packet: SensorPacket):
    """
    Endpoint otimizado para sensor_packet_t
    Recebe estrutura binária convertida para JSON
    """
    try:
        logger.info(f"📦 Pacote recebido: MAC={packet.mac}, "
                   f"value_id={packet.value_id}, dist={packet.distance_cm}cm")
        
        # Buscar sensor pelo value_id
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT sensor_id, elemento_id
                FROM supervisorio.sensores
                WHERE value_id = %s
                LIMIT 1
            """, (packet.value_id,))
            
            sensor = cursor.fetchone()
            
            if not sensor:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Sensor value_id={packet.value_id} não encontrado"
                )
            
            # Inserir leitura
            cursor.execute("""
                INSERT INTO supervisorio.leituras_raw 
                (sensor_id, valor, rssi, mac_address, sequence)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING leitura_id
            """, (
                sensor['sensor_id'],
                packet.distance_cm,
                packet.rssi,
                packet.mac,
                packet.sequence
            ))
            
            leitura_id = cursor.fetchone()['leitura_id']
            
            logger.info(f"✅ Pacote processado: leitura_id={leitura_id}")
        
        return {
            "status": "success",
            "leitura_id": leitura_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Erro ao processar pacote: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

@router.get("/processadas")
async def listar_leituras_processadas(
    sensor_id: Optional[int] = None,
    elemento_id: Optional[int] = None,
    limit: int = 100
):
    """Lista leituras processadas (comprimidas)"""
    try:
        with get_cursor() as cursor:
            query = """
                SELECT 
                    lp.leitura_proc_id,
                    lp.sensor_id,
                    s.value_id,
                    s.elemento_id,
                    e.nome_elemento,
                    lp.valor_mediana,
                    lp.timestamp_inicio,
                    lp.timestamp_fim,
                    lp.num_amostras
                FROM supervisorio.leituras_processadas lp
                JOIN supervisorio.sensores s ON lp.sensor_id = s.sensor_id
                JOIN supervisorio.elemento e ON s.elemento_id = e.elemento_id
                WHERE 1=1
            """
            
            params = []
            if sensor_id:
                query += " AND lp.sensor_id = %s"
                params.append(sensor_id)
            
            if elemento_id:
                query += " AND s.elemento_id = %s"
                params.append(elemento_id)
            
            query += " ORDER BY lp.timestamp_fim DESC LIMIT %s"
            params.append(limit)
            
            cursor.execute(query, params)
            leituras = cursor.fetchall()
        
        return {
            "total": len(leituras),
            "leituras": leituras
        }
        
    except Exception as e:
        logger.error(f"Erro ao listar leituras processadas: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/stats/{sensor_id}")
async def estatisticas_sensor(sensor_id: int):
    """Estatísticas de um sensor específico"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    COUNT(*) as total_leituras,
                    AVG(valor) as media,
                    MIN(valor) as minimo,
                    MAX(valor) as maximo,
                    STDDEV(valor) as desvio_padrao,
                    MAX(timestamp) as ultima_leitura
                FROM supervisorio.leituras_raw
                WHERE sensor_id = %s
                  AND timestamp > NOW() - INTERVAL '24 hours'
            """, (sensor_id,))
            
            stats = cursor.fetchone()
        
        return stats
        
    except Exception as e:
        logger.error(f"Erro ao obter estatísticas: {e}")
        raise HTTPException(status_code=500, detail=str(e))

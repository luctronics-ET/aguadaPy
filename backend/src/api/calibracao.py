"""
Endpoints para calibração manual de sensores
"""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from datetime import datetime
import logging

from ..database import get_cursor

logger = logging.getLogger(__name__)

router = APIRouter()

# ==================== MODELOS ====================

class CalibracaoManual(BaseModel):
    sensor_id: int
    valor_manual: float
    observacoes: str = ""

# ==================== ENDPOINTS ====================

@router.post("/", status_code=status.HTTP_201_CREATED)
async def registrar_calibracao(calibracao: CalibracaoManual):
    """Registra calibração manual de sensor"""
    try:
        with get_cursor() as cursor:
            # Obter última leitura do sensor
            cursor.execute("""
                SELECT valor, timestamp
                FROM supervisorio.leituras_raw
                WHERE sensor_id = %s
                ORDER BY timestamp DESC
                LIMIT 1
            """, (calibracao.sensor_id,))
            
            ultima_leitura = cursor.fetchone()
            
            if not ultima_leitura:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Sensor {calibracao.sensor_id} sem leituras"
                )
            
            # Calcular diferença
            diferenca = calibracao.valor_manual - ultima_leitura['valor']
            
            # Inserir calibração
            cursor.execute("""
                INSERT INTO supervisorio.calibracoes
                (sensor_id, valor_lido, valor_real, diferenca, observacoes)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING calibracao_id, timestamp
            """, (
                calibracao.sensor_id,
                ultima_leitura['valor'],
                calibracao.valor_manual,
                diferenca,
                calibracao.observacoes
            ))
            
            result = cursor.fetchone()
            
            logger.info(f"✅ Calibração registrada: sensor={calibracao.sensor_id}, "
                       f"diff={diferenca:.2f}cm")
        
        return {
            "status": "success",
            "calibracao_id": result['calibracao_id'],
            "timestamp": result['timestamp'].isoformat(),
            "diferenca_cm": diferenca
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao registrar calibração: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{sensor_id}")
async def historico_calibracoes(sensor_id: int, limit: int = 10):
    """Histórico de calibrações de um sensor"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    calibracao_id,
                    timestamp,
                    valor_lido,
                    valor_real,
                    diferenca,
                    observacoes
                FROM supervisorio.calibracoes
                WHERE sensor_id = %s
                ORDER BY timestamp DESC
                LIMIT %s
            """, (sensor_id, limit))
            
            calibracoes = cursor.fetchall()
        
        return {
            "sensor_id": sensor_id,
            "total": len(calibracoes),
            "calibracoes": calibracoes
        }
        
    except Exception as e:
        logger.error(f"Erro ao obter histórico de calibrações: {e}")
        raise HTTPException(status_code=500, detail=str(e))

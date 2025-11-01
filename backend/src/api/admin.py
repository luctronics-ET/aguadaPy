"""
Rotas para administração do sistema
"""
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional
import logging

from ..worker import process_compression_queue, cleanup_old_queue_items

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["admin"])


class ProcessQueueResponse(BaseModel):
    success: bool
    message: str
    stats: dict


@router.post("/process-queue", response_model=ProcessQueueResponse)
async def trigger_process_queue(
    background_tasks: BackgroundTasks,
    limit: Optional[int] = 100
):
    """
    Força processamento da fila de compressão
    
    Útil para processar leituras que não atingiram o window_size
    """
    try:
        # Processar em background para não bloquear a resposta
        background_tasks.add_task(process_compression_queue, limit)
        
        return ProcessQueueResponse(
            success=True,
            message=f"Processamento da fila iniciado (até {limit} itens)",
            stats={}
        )
        
    except Exception as e:
        logger.error(f"Erro ao processar fila: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/cleanup-queue")
async def trigger_cleanup_queue(days: Optional[int] = 7):
    """
    Remove itens antigos já processados da fila
    """
    try:
        deleted = cleanup_old_queue_items(days)
        
        return {
            "success": True,
            "message": f"Limpeza concluída",
            "deleted": deleted
        }
        
    except Exception as e:
        logger.error(f"Erro ao limpar fila: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/queue-status")
async def get_queue_status():
    """
    Retorna estatísticas da fila de processamento
    """
    from ..database import get_db_connection
    
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Total pendente
        cursor.execute("""
            SELECT COUNT(*) 
            FROM supervisorio.processing_queue 
            WHERE processed = FALSE
        """)
        pending = cursor.fetchone()[0]
        
        # Total processado
        cursor.execute("""
            SELECT COUNT(*) 
            FROM supervisorio.processing_queue 
            WHERE processed = TRUE
        """)
        processed = cursor.fetchone()[0]
        
        # Erros
        cursor.execute("""
            SELECT COUNT(*) 
            FROM supervisorio.processing_queue 
            WHERE error IS NOT NULL
        """)
        errors = cursor.fetchone()[0]
        
        # Sensores pendentes
        cursor.execute("""
            SELECT sensor_id, COUNT(*) as count
            FROM supervisorio.processing_queue 
            WHERE processed = FALSE
            GROUP BY sensor_id
            ORDER BY count DESC
        """)
        sensors_pending = [
            {"sensor_id": row[0], "count": row[1]} 
            for row in cursor.fetchall()
        ]
        
        cursor.close()
        
        return {
            "pending": pending,
            "processed": processed,
            "errors": errors,
            "sensors_pending": sensors_pending
        }
        
    except Exception as e:
        logger.error(f"Erro ao buscar status da fila: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()

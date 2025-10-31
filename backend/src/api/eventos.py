"""
Endpoints para eventos detectados
(Vazamentos, Abastecimentos, Consumos)
"""

from fastapi import APIRouter, HTTPException
from typing import Optional
import logging

from ..database import get_cursor

logger = logging.getLogger(__name__)

router = APIRouter()

@router.get("/")
async def listar_eventos(
    elemento_id: Optional[int] = None,
    tipo_evento: Optional[str] = None,
    limit: int = 100
):
    """Lista eventos detectados pelo sistema"""
    try:
        with get_cursor() as cursor:
            query = """
                SELECT 
                    ev.evento_id,
                    ev.elemento_id,
                    e.nome_elemento,
                    ev.tipo_evento,
                    ev.timestamp_inicio,
                    ev.timestamp_fim,
                    ev.variacao_nivel,
                    ev.taxa_variacao,
                    ev.volume_estimado,
                    ev.severidade,
                    ev.resolvido
                FROM supervisorio.eventos ev
                JOIN supervisorio.elemento e ON ev.elemento_id = e.elemento_id
                WHERE 1=1
            """
            
            params = []
            
            if elemento_id:
                query += " AND ev.elemento_id = %s"
                params.append(elemento_id)
            
            if tipo_evento:
                query += " AND ev.tipo_evento = %s"
                params.append(tipo_evento)
            
            query += " ORDER BY ev.timestamp_inicio DESC LIMIT %s"
            params.append(limit)
            
            cursor.execute(query, params)
            eventos = cursor.fetchall()
        
        return {
            "total": len(eventos),
            "eventos": eventos
        }
        
    except Exception as e:
        logger.error(f"Erro ao listar eventos: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/criticos")
async def eventos_criticos():
    """Lista eventos críticos não resolvidos"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    ev.*,
                    e.nome_elemento,
                    e.tipo
                FROM supervisorio.eventos ev
                JOIN supervisorio.elemento e ON ev.elemento_id = e.elemento_id
                WHERE ev.severidade IN ('CRITICA', 'ALTA')
                  AND ev.resolvido = FALSE
                ORDER BY ev.timestamp_inicio DESC
                LIMIT 50
            """)
            
            eventos = cursor.fetchall()
        
        return {
            "total": len(eventos),
            "eventos_criticos": eventos
        }
        
    except Exception as e:
        logger.error(f"Erro ao listar eventos críticos: {e}")
        raise HTTPException(status_code=500, detail=str(e))

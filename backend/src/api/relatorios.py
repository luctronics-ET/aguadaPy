"""
Endpoints para relatórios
"""

from fastapi import APIRouter, HTTPException
from datetime import date, datetime
import logging

from ..database import get_cursor

logger = logging.getLogger(__name__)

router = APIRouter()

@router.get("/diario/{data}")
async def relatorio_diario(data: date):
    """Relatório diário gerado automaticamente"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT *
                FROM supervisorio.relatorios_diarios
                WHERE data_relatorio = %s
            """, (data,))
            
            relatorio = cursor.fetchone()
            
            if not relatorio:
                raise HTTPException(
                    status_code=404,
                    detail=f"Relatório para {data} não encontrado"
                )
        
        return relatorio
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao obter relatório: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/dashboard")
async def resumo_dashboard():
    """Resumo para dashboard principal"""
    try:
        with get_cursor() as cursor:
            # Total de elementos
            cursor.execute("SELECT COUNT(*) as total FROM supervisorio.elemento")
            total_elementos = cursor.fetchone()['total']
            
            # Eventos nas últimas 24h
            cursor.execute("""
                SELECT COUNT(*) as total
                FROM supervisorio.eventos
                WHERE timestamp_inicio > NOW() - INTERVAL '24 hours'
            """)
            eventos_24h = cursor.fetchone()['total']
            
            # Eventos críticos não resolvidos
            cursor.execute("""
                SELECT COUNT(*) as total
                FROM supervisorio.eventos
                WHERE severidade IN ('CRITICA', 'ALTA')
                  AND resolvido = FALSE
            """)
            eventos_criticos = cursor.fetchone()['total']
            
            # Sensores ativos
            cursor.execute("""
                SELECT COUNT(*) as total
                FROM supervisorio.sensores
                WHERE status = 'ATIVO'
            """)
            sensores_ativos = cursor.fetchone()['total']
        
        return {
            "total_elementos": total_elementos,
            "eventos_24h": eventos_24h,
            "eventos_criticos": eventos_criticos,
            "sensores_ativos": sensores_ativos,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Erro ao gerar resumo dashboard: {e}")
        raise HTTPException(status_code=500, detail=str(e))

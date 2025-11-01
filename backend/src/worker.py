"""
Worker para processar fila de compressão de leituras
"""
import logging
from typing import Optional
from .database import get_db_connection

logger = logging.getLogger(__name__)

def process_compression_queue(limit: int = 100) -> dict:
    """
    Processa itens da fila de compressão
    
    Args:
        limit: Número máximo de itens a processar
        
    Returns:
        dict com estatísticas do processamento
    """
    conn = None
    stats = {
        'processados': 0,
        'erros': 0,
        'sensores_unicos': set()
    }
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Buscar sensores com itens pendentes na fila
        cursor.execute("""
            SELECT DISTINCT sensor_id, MIN(enqueued_at) as first_queued
            FROM supervisorio.processing_queue
            WHERE processed = FALSE
            GROUP BY sensor_id
            ORDER BY first_queued
            LIMIT %s
        """, (limit,))
        
        sensors = cursor.fetchall()
        
        for row in sensors:
            sensor_id = row[0]  # Primeira coluna é o sensor_id
            try:
                # Definir search_path antes de chamar a função
                cursor.execute("SET search_path = supervisorio, public")
                
                # Chamar função de processamento
                cursor.execute("""
                    SELECT supervisorio.proc_process_sensor_window(%s)
                """, (sensor_id,))
                
                # Marcar itens da fila como processados
                cursor.execute("""
                    UPDATE supervisorio.processing_queue
                    SET processed = TRUE,
                        processed_at = NOW()
                    WHERE sensor_id = %s
                      AND processed = FALSE
                """, (sensor_id,))
                
                conn.commit()
                
                stats['processados'] += cursor.rowcount
                stats['sensores_unicos'].add(sensor_id)
                
                logger.info(f"✅ Processado sensor {sensor_id}")
                
            except Exception as e:
                logger.error(f"❌ Erro ao processar sensor {sensor_id}: {e}")
                conn.rollback()
                
                # Marcar como erro na fila
                cursor.execute("""
                    UPDATE supervisorio.processing_queue
                    SET error = %s
                    WHERE sensor_id = %s
                      AND processed = FALSE
                """, (str(e), sensor_id))
                conn.commit()
                
                stats['erros'] += 1
        
        cursor.close()
        
    except Exception as e:
        logger.error(f"❌ Erro ao processar fila: {e}")
        if conn:
            conn.rollback()
    finally:
        if conn:
            conn.close()
    
    stats['sensores_unicos'] = len(stats['sensores_unicos'])
    return stats


def cleanup_old_queue_items(days: int = 7) -> int:
    """
    Remove itens antigos já processados da fila
    
    Args:
        days: Número de dias para manter histórico
        
    Returns:
        Número de registros removidos
    """
    conn = None
    deleted = 0
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            DELETE FROM supervisorio.processing_queue
            WHERE processed = TRUE
              AND processed_at < NOW() - INTERVAL '%s days'
        """, (days,))
        
        deleted = cursor.rowcount
        conn.commit()
        cursor.close()
        
        if deleted > 0:
            logger.info(f"🧹 Removidos {deleted} itens antigos da fila")
        
    except Exception as e:
        logger.error(f"❌ Erro ao limpar fila: {e}")
        if conn:
            conn.rollback()
    finally:
        if conn:
            conn.close()
    
    return deleted

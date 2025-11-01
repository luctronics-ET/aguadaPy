"""
API endpoints para dashboard
"""
from fastapi import APIRouter, HTTPException
from typing import List, Dict, Any
import logging
from ..database import get_db

router = APIRouter(prefix="/api", tags=["Dashboard"])
logger = logging.getLogger(__name__)


@router.get("/test")
async def test_endpoint():
    """Endpoint de teste"""
    return {"status": "ok", "message": "Dashboard API funcionando"}


@router.get("/leituras/ultimas")
async def get_ultimas_leituras() -> List[Dict[str, Any]]:
    """Retorna as últimas leituras de todos os sensores"""
    try:
        conn = get_db()
        cursor = conn.cursor()
        
        # Query completa - sensores com última leitura
        query = """
            SELECT 
                s.sensor_id,
                s.elemento_id,
                s.tipo,
                s.modelo,
                s.unidade,
                lr.valor,
                lr.datetime,
                lr.observacao
            FROM supervisorio.sensores s
            LEFT JOIN LATERAL (
                SELECT valor, datetime, observacao
                FROM supervisorio.leituras_raw
                WHERE sensor_id = s.sensor_id
                ORDER BY datetime DESC
                LIMIT 1
            ) lr ON true
            ORDER BY s.sensor_id
        """
        logger.info(f"🔍 Executando query completa")
        
        cursor.execute(query)
        rows = cursor.fetchall()
        
        logger.info(f"📊 Retornadas {len(rows)} linhas")
        
        sensores = []
        for row in rows:
            sensor = {
                "sensor_id": row['sensor_id'],
                "elemento_id": row['elemento_id'],
                "tipo": row['tipo'],
                "modelo": row['modelo'],
                "unidade": row['unidade'],
                "ultima_distancia": float(row['valor']) if row['valor'] is not None else None,
                "ultima_leitura": row['datetime'].isoformat() if row['datetime'] else None,
                "observacao": row['observacao']
            }
            sensores.append(sensor)
        
        cursor.close()
        conn.close()
        
        logger.info(f"✅ Retornando {len(sensores)} sensores")
        return sensores
        
    except Exception as e:
        logger.error(f"❌ Erro ao buscar últimas leituras: {e}")
        logger.error(f"   Tipo do erro: {type(e)}")
        import traceback
        logger.error(f"   Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Erro: {type(e).__name__} - {str(e)}")


@router.get("/sensores/estatisticas/{sensor_id}")
async def get_sensor_stats(sensor_id: str) -> Dict[str, Any]:
    """
    Retorna estatísticas de um sensor específico
    """
    try:
        conn = get_db()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT 
                COUNT(*) as total,
                MIN(valor) as min_valor,
                MAX(valor) as max_valor,
                AVG(valor) as avg_valor,
                MIN(datetime) as primeira_leitura,
                MAX(datetime) as ultima_leitura
            FROM supervisorio.leituras_raw
            WHERE sensor_id = %s
        """, (sensor_id,))
        
        row = cursor.fetchone()
        
        if row and row['total'] > 0:
            stats = {
                "sensor_id": sensor_id,
                "total_leituras": row['total'],
                "min_distancia": float(row['min_valor']),
                "max_distancia": float(row['max_valor']),
                "avg_distancia": float(row['avg_valor']),
                "primeira_leitura": row['primeira_leitura'].isoformat(),
                "ultima_leitura": row['ultima_leitura'].isoformat()
            }
        else:
            stats = {
                "sensor_id": sensor_id,
                "total_leituras": 0,
                "message": "Nenhuma leitura encontrada"
            }
        
        cursor.close()
        conn.close()
        
        return stats
        
    except Exception as e:
        logger.error(f"❌ Erro ao buscar estatísticas: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/sensores/historico/{sensor_id}")
async def get_sensor_history(sensor_id: str, limit: int = 100) -> List[Dict[str, Any]]:
    """
    Retorna histórico de leituras de um sensor
    """
    try:
        conn = get_db()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT 
                leitura_id,
                valor,
                datetime,
                observacao
            FROM supervisorio.leituras_raw
            WHERE sensor_id = %s
            ORDER BY datetime DESC
            LIMIT %s
        """, (sensor_id, limit))
        
        history = []
        for row in cursor.fetchall():
            history.append({
                "leitura_id": row['leitura_id'],
                "valor": float(row['valor']),
                "datetime": row['datetime'].isoformat(),
                "observacao": row['observacao']
            })
        
        cursor.close()
        conn.close()
        
        return history
        
    except Exception as e:
        logger.error(f"❌ Erro ao buscar histórico: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/consumo/hoje")
async def get_consumo_hoje() -> Dict[str, Any]:
    """
    Retorna consumo, abastecimento e perdas do dia atual
    """
    try:
        conn = get_db()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT * FROM supervisorio.calcular_consumo_diario(CURRENT_DATE)
        """)
        
        reservatorios = []
        consumo_total = 0
        abastecimento_total = 0
        perda_total = 0
        
        for row in cursor.fetchall():
            reservatorios.append({
                "elemento_id": row['elemento_id'],
                "nome": row['nome_elemento'],
                "consumo_litros": float(row['consumo_litros']) if row['consumo_litros'] else 0,
                "abastecimento_litros": float(row['abastecimento_litros']) if row['abastecimento_litros'] else 0,
                "perda_litros": float(row['perda_litros']) if row['perda_litros'] else 0
            })
            consumo_total += float(row['consumo_litros']) if row['consumo_litros'] else 0
            abastecimento_total += float(row['abastecimento_litros']) if row['abastecimento_litros'] else 0
            perda_total += float(row['perda_litros']) if row['perda_litros'] else 0
        
        cursor.close()
        conn.close()
        
        return {
            "data": "hoje",
            "consumo_total_litros": consumo_total,
            "consumo_total_m3": consumo_total / 1000,
            "abastecimento_total_litros": abastecimento_total,
            "abastecimento_total_m3": abastecimento_total / 1000,
            "perda_total_litros": perda_total,
            "perda_total_m3": perda_total / 1000,
            "reservatorios": reservatorios
        }
        
    except Exception as e:
        logger.error(f"❌ Erro ao calcular consumo: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/consumo/periodo")
async def get_consumo_periodo(dias: int = 7) -> List[Dict[str, Any]]:
    """
    Retorna consumo dos últimos N dias
    """
    try:
        conn = get_db()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT 
                data,
                consumo_total_litros,
                abastecimento_total_litros,
                perda_total_litros
            FROM supervisorio.relatorio_diario
            WHERE data >= CURRENT_DATE - INTERVAL '%s days'
            ORDER BY data DESC
        """, (dias,))
        
        historico = []
        for row in cursor.fetchall():
            historico.append({
                "data": row['data'].isoformat() if row['data'] else None,
                "consumo_litros": float(row['consumo_total_litros']) if row['consumo_total_litros'] else 0,
                "consumo_m3": float(row['consumo_total_litros']) / 1000 if row['consumo_total_litros'] else 0,
                "abastecimento_litros": float(row['abastecimento_total_litros']) if row['abastecimento_total_litros'] else 0,
                "abastecimento_m3": float(row['abastecimento_total_litros']) / 1000 if row['abastecimento_total_litros'] else 0,
                "perda_litros": float(row['perda_total_litros']) if row['perda_total_litros'] else 0,
                "perda_m3": float(row['perda_total_litros']) / 1000 if row['perda_total_litros'] else 0
            })
        
        cursor.close()
        conn.close()
        
        return historico
        
    except Exception as e:
        logger.error(f"❌ Erro ao buscar consumo período: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/atividades/recentes")
async def get_atividades_recentes(limit: int = 50):
    """
    Retorna atividades recentes (leituras processadas) sem repetições
    
    Mostra apenas mudanças significativas nos últimos 7 dias
    """
    try:
        conn = get_db()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT 
                proc_id,
                elemento,
                variavel,
                valor,
                unidade,
                datetime,
                n_amostras,
                percentual
            FROM supervisorio.v_atividades_dashboard
            LIMIT %s
        """, (limit,))
        
        atividades = cursor.fetchall()
        cursor.close()
        
        return {
            "total": len(atividades),
            "atividades": atividades
        }
        
    except Exception as e:
        logger.error(f"Erro ao buscar atividades: {e}")
        raise HTTPException(status_code=500, detail=str(e))


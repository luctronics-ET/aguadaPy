"""
Endpoints para gerenciamento de elementos
(Reservatórios, Bombas, Válvulas, etc)
"""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional
import logging

from ..database import get_cursor

logger = logging.getLogger(__name__)

router = APIRouter()

# ==================== MODELOS ====================

class ElementoResponse(BaseModel):
    elemento_id: int
    nome_elemento: str
    tipo: str
    capacidade: Optional[float] = None
    nivel_atual: Optional[float] = None
    status: Optional[str] = None

# ==================== ENDPOINTS ====================

@router.get("/stats")
async def estatisticas_elementos():
    """Estatísticas dos elementos"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    tipo,
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE ativo = true) as ativos
                FROM supervisorio.elemento
                GROUP BY tipo
            """)
            
            stats_raw = cursor.fetchall()
            
            # Formatar resultado
            stats = {
                'total': 0,
                'ativos': 0
            }
            
            for row in stats_raw:
                tipo = row['tipo']
                stats[tipo] = row['total']
                stats['total'] += row['total']
                stats['ativos'] += row['ativos']
        
        return stats
        
    except Exception as e:
        logger.error(f"Erro ao obter estatísticas: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/coordenadas")
async def get_elementos_coordenadas():
    """Retorna uma lista de elementos com suas coordenadas para o mapa."""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    e.id,
                    e.nome,
                    e.tipo,
                    e.status_operacional as status,
                    c.latitude,
                    c.longitude
                FROM supervisorio.elemento e
                JOIN supervisorio.coordenada c ON e.id = c.elemento_id
                WHERE c.latitude IS NOT NULL AND c.longitude IS NOT NULL
                ORDER BY e.tipo, e.nome;
            """)
            coordenadas = cursor.fetchall()
        return coordenadas
    except Exception as e:
        logger.error(f"Erro ao buscar coordenadas dos elementos: {e}")
        raise HTTPException(status_code=500, detail="Erro ao buscar coordenadas.")

@router.get("/")
async def listar_elementos(tipo: Optional[str] = None):
    """Lista todos os elementos do sistema"""
    try:
        with get_cursor() as cursor:
            query = """
                SELECT 
                    e.id,
                    e.elemento_id,
                    e.nome,
                    e.tipo,
                    e.capacidade_litros,
                    e.altura_base_m,
                    e.status_operacional as status,
                    e.descricao,
                    e.ativo,
                    e.fabricante,
                    e.modelo,
                    e.instalado_em,
                    c.coord_x,
                    c.coord_y,
                    c.coord_z,
                    c.latitude,
                    c.longitude,
                    (
                        SELECT valor
                        FROM supervisorio.leituras_processadas
                        WHERE elemento_id = e.id 
                        AND variavel = 'nivel_cm'
                        ORDER BY data_fim DESC
                        LIMIT 1
                    ) as nivel_atual
                FROM supervisorio.elemento e
                LEFT JOIN supervisorio.coordenada c ON e.id = c.elemento_id
                WHERE 1=1
            """
            
            params = []
            if tipo:
                query += " AND e.tipo = %s"
                params.append(tipo)
            
            query += " ORDER BY e.nome"
            
            cursor.execute(query, params)
            elementos = cursor.fetchall()
        
        return elementos
        
    except Exception as e:
        logger.error(f"Erro ao listar elementos: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{elemento_id}")
async def detalhe_elemento(elemento_id: int):
    """Detalhes de um elemento específico"""
    try:
        with get_cursor() as cursor:
            # Dados do elemento
            cursor.execute("""
                SELECT 
                    e.id,
                    e.elemento_id,
                    e.nome,
                    e.tipo,
                    e.descricao,
                    e.capacidade_litros,
                    e.altura_base_m,
                    e.status_operacional as status,
                    e.ativo,
                    e.fabricante,
                    e.modelo,
                    e.instalado_em,
                    c.coord_x,
                    c.coord_y,
                    c.coord_z,
                    c.latitude,
                    c.longitude,
                    c.altitude_m
                FROM supervisorio.elemento e
                LEFT JOIN supervisorio.coordenada c ON e.id = c.elemento_id
                WHERE e.id = %s
            """, (elemento_id,))
            
            elemento = cursor.fetchone()
            
            if not elemento:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Elemento {elemento_id} não encontrado"
                )
            
            # Criar objeto meta
            meta = {}
            if elemento.get('fabricante'):
                meta['fabricante'] = elemento['fabricante']
            if elemento.get('modelo'):
                meta['modelo'] = elemento['modelo']
            if elemento.get('instalado_em'):
                meta['data_instalacao'] = elemento['instalado_em']
            
            # Formatar resposta
            result = {
                'id': elemento['id'],
                'elemento_id': elemento['elemento_id'],
                'nome': elemento['nome'],
                'tipo': elemento['tipo'],
                'descricao': elemento['descricao'],
                'capacidade_litros': elemento['capacidade_litros'],
                'altura_base_m': elemento['altura_base_m'],
                'status': elemento['status'],
                'ativo': elemento['ativo'],
                'coord_x': elemento['coord_x'],
                'coord_y': elemento['coord_y'],
                'coord_z': elemento['coord_z'],
                'latitude': elemento['latitude'],
                'longitude': elemento['longitude'],
                'meta': meta if meta else None
            }
            
            # Sensores do elemento
            cursor.execute("""
                SELECT 
                    sensor_id,
                    tipo,
                    modelo,
                    unidade,
                    estado_operacional as status
                FROM supervisorio.sensores
                WHERE elemento_id = %s
            """, (elemento_id,))
            
            sensores = cursor.fetchall()
            
            # Última leitura de nível
            cursor.execute("""
                SELECT 
                    lp.valor,
                    lp.data_fim as datetime
                FROM supervisorio.leituras_processadas lp
                WHERE lp.elemento_id = %s
                  AND lp.variavel = 'nivel_cm'
                ORDER BY lp.data_fim DESC
                LIMIT 1
            """, (elemento_id,))
            
            ultima_leitura = cursor.fetchone()
        
        return {
            **result,
            "sensores": sensores,
            "ultima_leitura": ultima_leitura
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao obter detalhes do elemento: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{elemento_id}/historico")
async def historico_elemento(
    elemento_id: int,
    horas: int = 24,
    limit: int = 1000
):
    """Histórico de leituras de um elemento"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    lp.valor_mediana,
                    lp.timestamp_fim,
                    lp.num_amostras,
                    lp.variavel,
                    lp.unidade
                FROM supervisorio.leituras_processadas lp
                WHERE lp.elemento_id = %s
                  AND lp.data_fim > NOW() - INTERVAL '%s hours'
                ORDER BY lp.data_fim DESC
                LIMIT %s
            """, (elemento_id, horas, limit))
            
            historico = cursor.fetchall()
        
        return {
            "elemento_id": elemento_id,
            "periodo_horas": horas,
            "total": len(historico),
            "historico": historico
        }
        
    except Exception as e:
        logger.error(f"Erro ao obter histórico: {e}")
        raise HTTPException(status_code=500, detail=str(e))

class ElementoCreate(BaseModel):
    nome: str
    tipo: str
    descricao: Optional[str] = None
    capacidade_litros: Optional[float] = None
    coord_x: Optional[float] = None
    coord_y: Optional[float] = None
    coord_z: Optional[float] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    ativo: bool = True
    meta: Optional[dict] = None

@router.post("/")
async def criar_elemento(elemento: ElementoCreate):
    """Criar novo elemento"""
    try:
        with get_cursor() as cursor:
            # Gerar elemento_id baseado no tipo e próximo número
            tipo_prefix = {
                'reservatorio': 'RES',
                'bomba': 'BOMB',
                'valvula': 'VALV',
                'sensor': 'SEN',
                'rede': 'REDE',
                'consumidor': 'CONS'
            }
            
            prefix = tipo_prefix.get(elemento.tipo, 'ELEM')
            
            # Buscar próximo número disponível
            cursor.execute("""
                SELECT COUNT(*) + 1 as next_num
                FROM supervisorio.elemento 
                WHERE tipo = %s
            """, (elemento.tipo,))
            
            result = cursor.fetchone()
            next_num = result['next_num']
            elemento_id = f"{prefix}{next_num:03d}"
            
            # Inserir elemento
            cursor.execute("""
                INSERT INTO supervisorio.elemento (
                    elemento_id, nome, tipo, descricao, 
                    capacidade_litros, ativo,
                    fabricante, modelo, instalado_em
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s
                ) RETURNING id
            """, (
                elemento_id,
                elemento.nome,
                elemento.tipo,
                elemento.descricao,
                elemento.capacidade_litros,
                elemento.ativo,
                elemento.meta.get('fabricante') if elemento.meta else None,
                elemento.meta.get('modelo') if elemento.meta else None,
                elemento.meta.get('data_instalacao') if elemento.meta else None
            ))
            
            result = cursor.fetchone()
            new_id = result['id']
            
            # Inserir coordenadas se fornecidas
            if any([elemento.coord_x, elemento.coord_y, elemento.coord_z, 
                   elemento.latitude, elemento.longitude]):
                cursor.execute("""
                    INSERT INTO supervisorio.coordenada (
                        elemento_id, coord_x, coord_y, coord_z,
                        latitude, longitude
                    ) VALUES (%s, %s, %s, %s, %s, %s)
                """, (
                    new_id,
                    elemento.coord_x,
                    elemento.coord_y,
                    elemento.coord_z,
                    elemento.latitude,
                    elemento.longitude
                ))
        
        logger.info(f"Elemento criado: {elemento_id} (ID: {new_id})")
        
        return {
            "id": new_id,
            "elemento_id": elemento_id,
            "message": "Elemento criado com sucesso"
        }
        
    except Exception as e:
        logger.error(f"Erro ao criar elemento: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{elemento_id}")
async def atualizar_elemento(elemento_id: int, elemento: ElementoCreate):
    """Atualizar elemento existente"""
    try:
        with get_cursor() as cursor:
            # Atualizar elemento
            cursor.execute("""
                UPDATE supervisorio.elemento
                SET nome = %s,
                    tipo = %s,
                    descricao = %s,
                    capacidade_litros = %s,
                    ativo = %s,
                    fabricante = %s,
                    modelo = %s,
                    instalado_em = %s,
                    atualizado_em = NOW()
                WHERE id = %s
            """, (
                elemento.nome,
                elemento.tipo,
                elemento.descricao,
                elemento.capacidade_litros,
                elemento.ativo,
                elemento.meta.get('fabricante') if elemento.meta else None,
                elemento.meta.get('modelo') if elemento.meta else None,
                elemento.meta.get('data_instalacao') if elemento.meta else None,
                elemento_id
            ))
            
            if cursor.rowcount == 0:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Elemento {elemento_id} não encontrado"
                )
            
            # Atualizar ou inserir coordenadas
            if any([elemento.coord_x, elemento.coord_y, elemento.coord_z,
                   elemento.latitude, elemento.longitude]):
                cursor.execute("""
                    INSERT INTO supervisorio.coordenada (
                        elemento_id, coord_x, coord_y, coord_z,
                        latitude, longitude
                    ) VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT (elemento_id) DO UPDATE SET
                        coord_x = EXCLUDED.coord_x,
                        coord_y = EXCLUDED.coord_y,
                        coord_z = EXCLUDED.coord_z,
                        latitude = EXCLUDED.latitude,
                        longitude = EXCLUDED.longitude
                """, (
                    elemento_id,
                    elemento.coord_x,
                    elemento.coord_y,
                    elemento.coord_z,
                    elemento.latitude,
                    elemento.longitude
                ))
        
        logger.info(f"Elemento {elemento_id} atualizado")
        
        return {
            "id": elemento_id,
            "message": "Elemento atualizado com sucesso"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao atualizar elemento: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{elemento_id}")
async def deletar_elemento(elemento_id: int):
    """Deletar elemento"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                DELETE FROM supervisorio.elemento
                WHERE id = %s
            """, (elemento_id,))
            
            if cursor.rowcount == 0:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Elemento {elemento_id} não encontrado"
                )
        
        logger.info(f"Elemento {elemento_id} deletado")
        
        return {
            "message": "Elemento deletado com sucesso"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao deletar elemento: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/stats")
async def estatisticas_elementos():
    """Estatísticas dos elementos"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    tipo,
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE ativo = true) as ativos
                FROM supervisorio.elemento
                GROUP BY tipo
            """)
            
            stats_raw = cursor.fetchall()
            
            # Formatar resultado
            stats = {
                'total': 0,
                'ativos': 0
            }
            
            for row in stats_raw:
                tipo = row['tipo']
                stats[tipo] = row['total']
                stats['total'] += row['total']
                stats['ativos'] += row['ativos']
        
        return stats
        
    except Exception as e:
        logger.error(f"Erro ao obter estatísticas: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/coordenadas")
async def get_elementos_coordenadas():
    """Retorna uma lista de elementos com suas coordenadas para o mapa."""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    e.id,
                    e.nome,
                    e.tipo,
                    e.status_operacional as status,
                    c.latitude,
                    c.longitude
                FROM supervisorio.elemento e
                JOIN supervisorio.coordenada c ON e.id = c.elemento_id
                WHERE c.latitude IS NOT NULL AND c.longitude IS NOT NULL
                ORDER BY e.tipo, e.nome;
            """)
            coordenadas = cursor.fetchall()
        return coordenadas
    except Exception as e:
        logger.error(f"Erro ao buscar coordenadas dos elementos: {e}")
        raise HTTPException(status_code=500, detail="Erro ao buscar coordenadas.")

@router.get("/{elemento_id}/conexoes")
async def listar_conexoes_elemento(elemento_id: int):
    """Lista conexões de um elemento"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    c.id,
                    c.tipo,
                    e_origem.nome as origem_nome,
                    e_origem.id as origem_id,
                    e_destino.nome as destino_nome,
                    e_destino.id as destino_id,
                    c.porta_origem,
                    c.porta_destino
                FROM supervisorio.conexao c
                JOIN supervisorio.elemento e_origem ON c.origem_id = e_origem.id
                JOIN supervisorio.elemento e_destino ON c.destino_id = e_destino.id
                WHERE c.origem_id = %s OR c.destino_id = %s
                ORDER BY c.id
            """, (elemento_id, elemento_id))
            
            conexoes = cursor.fetchall()
        
        return conexoes
        
    except Exception as e:
        logger.error(f"Erro ao listar conexões: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{elemento_id}/sensores")
async def listar_sensores_elemento(elemento_id: int):
    """Lista sensores de um elemento"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    sensor_id,
                    tipo,
                    modelo,
                    unidade,
                    estado_operacional as status
                FROM supervisorio.sensores
                WHERE elemento_id = %s
            """, (elemento_id,))
            
            sensores = cursor.fetchall()
        
        return sensores
        
    except Exception as e:
        logger.error(f"Erro ao listar sensores: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{elemento_id}/atuadores")
async def listar_atuadores_elemento(elemento_id: int):
    """Lista atuadores de um elemento"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    atuador_id,
                    tipo,
                    modelo,
                    estado_atual as estado
                FROM supervisorio.atuadores
                WHERE elemento_id = %s
            """, (elemento_id,))
            
            atuadores = cursor.fetchall()
        
        return atuadores
        
    except Exception as e:
        logger.error(f"Erro ao listar atuadores: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{elemento_id}/leituras")
async def listar_leituras_elemento(elemento_id: int, limit: int = 10):
    """Lista últimas leituras de um elemento"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    lp.valor,
                    lp.unidade,
                    lp.data_fim as datetime,
                    lp.variavel as tipo
                FROM supervisorio.leituras_processadas lp
                WHERE lp.elemento_id = %s
                ORDER BY lp.data_fim DESC
                LIMIT %s
            """, (elemento_id, limit))
            
            leituras = cursor.fetchall()
        
        return leituras
        
    except Exception as e:
        logger.error(f"Erro ao listar leituras: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{elemento_id}/eventos")
async def listar_eventos_elemento(elemento_id: int):
    """Lista eventos de um elemento"""
    try:
        with get_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    evento_id,
                    tipo,
                    detalhe,
                    datetime_inicio,
                    datetime_fim,
                    status,
                    severidade
                FROM supervisorio.eventos
                WHERE elemento_id = %s
                ORDER BY datetime_inicio DESC
                LIMIT 20
            """, (elemento_id,))
            
            eventos = cursor.fetchall()
        
        return eventos
        
    except Exception as e:
        logger.error(f"Erro ao listar eventos: {e}")
        raise HTTPException(status_code=500, detail=str(e))

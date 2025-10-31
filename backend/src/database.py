"""
Gerenciamento de conexão com PostgreSQL
"""

import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
import logging

from .config import settings

logger = logging.getLogger(__name__)

_connection_pool = None

def init_db():
    """Inicializa conexão com banco de dados"""
    global _connection_pool
    try:
        _connection_pool = psycopg2.connect(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            database=settings.DB_NAME,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
            cursor_factory=RealDictCursor
        )
        logger.info("✅ Pool de conexões PostgreSQL criado")
    except Exception as e:
        logger.error(f"❌ Erro ao conectar PostgreSQL: {e}")
        raise

def get_db():
    """Retorna conexão com banco de dados"""
    global _connection_pool
    if _connection_pool is None or _connection_pool.closed:
        init_db()
    return _connection_pool

@contextmanager
def get_cursor():
    """Context manager para cursor de banco"""
    conn = get_db()
    cursor = conn.cursor()
    try:
        yield cursor
        conn.commit()
    except Exception as e:
        conn.rollback()
        logger.error(f"Erro no banco de dados: {e}")
        raise
    finally:
        cursor.close()

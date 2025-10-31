   """
Backend API - Sistema Aguada CMMS/BMS
FastAPI + PostgreSQL
"""

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
from typing import Optional
import logging

from .database import get_db, init_db
from .api import leituras, elementos, eventos, relatorios, calibracao, dashboard
from .config import settings

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Gerencia o ciclo de vida da aplicação"""
    logger.info("🚀 Iniciando Backend Aguada CMMS/BMS")
    logger.info(f"📊 Ambiente: {settings.ENVIRONMENT}")
    logger.info(f"🗄️  Database: {settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}")
    
    # Inicializar conexão com banco
    try:
        init_db()
        logger.info("✅ Conexão com PostgreSQL estabelecida")
    except Exception as e:
        logger.error(f"❌ Erro ao conectar PostgreSQL: {e}")
        raise
    
    yield
    
    logger.info("🛑 Encerrando Backend Aguada")

# Criar aplicação FastAPI
app = FastAPI(
    title="Aguada CMMS/BMS API",
    description="API REST para Sistema de Supervisão Hídrica com IoT",
    version="1.0.0",
    lifespan=lifespan,
    redirect_slashes=False  # Desabilitar redirect automático de trailing slash
)

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Em produção, especificar domínios
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Rotas de leituras (ESP32/Arduino envia aqui)
app.include_router(leituras.router, prefix="/api/leituras", tags=["Leituras"])

# Rotas de elementos (reservatórios, bombas, válvulas)
app.include_router(elementos.router, prefix="/api/elementos", tags=["Elementos"])

# Rotas de eventos (vazamentos, abastecimentos)
app.include_router(eventos.router, prefix="/api/eventos", tags=["Eventos"])

# Rotas de relatórios
app.include_router(relatorios.router, prefix="/api/relatorios", tags=["Relatórios"])

# Rotas de calibração
app.include_router(calibracao.router, prefix="/api/calibracao", tags=["Calibração"])

# Rotas de dashboard
app.include_router(dashboard.router, tags=["Dashboard"])

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "online",
        "service": "Aguada CMMS/BMS API",
        "version": "1.0.0",
        "database": "connected"
    }

@app.get("/health")
async def health_check():
    """Verificação de saúde do sistema"""
    try:
        # Testa conexão com banco
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        
        return {
            "status": "healthy",
            "database": "connected",
            "timestamp": "NOW()"
        }
    except Exception as e:
        logger.error(f"Health check falhou: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Service unhealthy: {str(e)}"
        )

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Handler global de exceções"""
    logger.error(f"Erro não tratado: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Erro interno do servidor"}
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=3000,
        reload=True
    )

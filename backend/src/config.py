"""
Configurações da aplicação
Lê variáveis de ambiente do Docker
"""

from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    """Configurações do sistema"""
    
    # Ambiente
    ENVIRONMENT: str = "production"
    
    # Database
    DB_HOST: str = "postgres"
    DB_PORT: int = 5432
    DB_NAME: str = "aguada_cmms"
    DB_USER: str = "aguada_user"
    DB_PASSWORD: str = "aguada_pass_2025"
    
    # API
    API_PORT: int = 3000
    
    # JWT
    JWT_SECRET: str = "trocar_este_secret_em_producao"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_HOURS: int = 24
    
    # Timezone
    TZ: str = "America/Sao_Paulo"
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()

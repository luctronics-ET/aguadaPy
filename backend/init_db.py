#!/usr/bin/env python3
"""
Script de inicialização do banco de dados
Executa os scripts SQL na ordem correta
"""
import os
import time
import psycopg2
from pathlib import Path

def wait_for_db():
    """Aguarda o PostgreSQL estar pronto"""
    max_retries = 30
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            conn = psycopg2.connect(
                host=os.getenv('DB_HOST', 'postgres'),
                port=os.getenv('DB_PORT', '5432'),
                database=os.getenv('DB_NAME', 'aguada_cmms'),
                user=os.getenv('DB_USER', 'aguada_user'),
                password=os.getenv('DB_PASSWORD', 'aguada_pass_2025')
            )
            conn.close()
            print("✅ Banco de dados pronto!")
            return True
        except Exception as e:
            retry_count += 1
            print(f"⏳ Aguardando banco de dados... ({retry_count}/{max_retries})")
            time.sleep(2)
    
    print("❌ Timeout aguardando banco de dados")
    return False

def execute_sql_file(conn, filepath):
    """Executa um arquivo SQL com múltiplos statements"""
    with open(filepath, 'r', encoding='utf-8') as f:
        sql = f.read()
        try:
            # Usar cursor temporário para cada arquivo
            with conn.cursor() as cursor:
                # Execute todo o conteúdo do arquivo
                cursor.execute(sql)
            print(f"✅ Executado: {filepath}")
            return True
        except Exception as e:
            print(f"❌ Erro ao executar {filepath}: {e}")
            return False

def init_database():
    """Inicializa o banco de dados com os scripts SQL"""
    
    if not wait_for_db():
        return False
    
    try:
        # Conecta ao banco
        conn = psycopg2.connect(
            host=os.getenv('DB_HOST', 'postgres'),
            port=os.getenv('DB_PORT', '5432'),
            database=os.getenv('DB_NAME', 'aguada_cmms'),
            user=os.getenv('DB_USER', 'aguada_user'),
            password=os.getenv('DB_PASSWORD', 'aguada_pass_2025')
        )
        conn.autocommit = False
        
        # Verifica se o banco já foi inicializado
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_schema = 'supervisorio' 
                    AND table_name = 'elemento'
                );
            """)
            
            already_initialized = cursor.fetchone()[0]
        
        if already_initialized:
            print("ℹ️  Banco de dados já inicializado. Pulando scripts SQL.")
            conn.close()
            return True
        
        print("🚀 Inicializando banco de dados...")
        
        # Caminho base dos scripts (agora está em /app/database/)
        base_path = Path('/app/database')
        
        # Ordem de execução dos scripts
        scripts = [
            'schema.sql',
            'functions.sql',
            'triggers.sql',
            'seeds.sql'
        ]
        
        # Executa cada script
        for script in scripts:
            filepath = base_path / script
            if filepath.exists():
                if not execute_sql_file(conn, filepath):
                    conn.rollback()
                    conn.close()
                    return False
            else:
                print(f"⚠️  Script não encontrado: {filepath}")
        
        # Commit de todas as mudanças
        conn.commit()
        print("✅ Banco de dados inicializado com sucesso!")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Erro ao inicializar banco de dados: {e}")
        return False

if __name__ == '__main__':
    success = init_database()
    exit(0 if success else 1)

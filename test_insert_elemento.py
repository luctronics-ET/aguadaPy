#!/usr/bin/env python3
"""
Teste direto de inserção de elemento para debug
"""
import psycopg2
from psycopg2.extras import RealDictCursor

# Conexão direta
conn = psycopg2.connect(
    host="postgres",
    port=5432,
    database="aguada_cmms",
    user="aguada_user",
    password="aguada_pass_2025",
    cursor_factory=RealDictCursor
)

cursor = conn.cursor()

try:
    # Teste 1: COUNT com alias
    print("=" * 60)
    print("Teste 1: COUNT com alias")
    cursor.execute("""
        SELECT COUNT(*) + 1 as next_num
        FROM supervisorio.elemento 
        WHERE tipo = %s
    """, ("reservatorio",))
    
    result = cursor.fetchone()
    print(f"Resultado: {result}")
    print(f"Tipo: {type(result)}")
    print(f"next_num: {result['next_num']}")
    
    next_num = result['next_num']
    elemento_id = f"RES{next_num:03d}"
    print(f"Elemento ID gerado: {elemento_id}")
    
    # Teste 2: INSERT com RETURNING
    print("\n" + "=" * 60)
    print("Teste 2: INSERT com RETURNING")
    cursor.execute("""
        INSERT INTO supervisorio.elemento (
            elemento_id, nome, tipo, descricao, 
            capacidade_litros, ativo
        ) VALUES (
            %s, %s, %s, %s, %s, %s
        ) RETURNING id
    """, (
        elemento_id,
        "Reservatório Teste Python",
        "reservatorio",
        "Teste de inserção direta",
        50000,
        True
    ))
    
    result = cursor.fetchone()
    print(f"Resultado: {result}")
    print(f"Tipo: {type(result)}")
    print(f"new_id: {result['id']}")
    
    conn.commit()
    print(f"\n✅ Elemento criado com sucesso! ID: {result['id']}, elemento_id: {elemento_id}")
    
except Exception as e:
    print(f"\n❌ ERRO: {type(e).__name__}: {e}")
    import traceback
    traceback.print_exc()
    conn.rollback()
    
finally:
    cursor.close()
    conn.close()

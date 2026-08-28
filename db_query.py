import mysql.connector
import json

host = 'localhost'
user = 'balcao2p_user_eu'
password = 'Mysql26@'
database = 'balcao2p_vanpro'

try:
    conn = mysql.connector.connect(
        host=host,
        user=user,
        password=password,
        database=database
    )
    
    cursor = conn.cursor()
    results = {}
    
    # 1. SHOW TABLES
    cursor.execute("SHOW TABLES")
    tables = [table[0] for table in cursor.fetchall()]
    results['SHOW TABLES'] = tables
    
    # 2. DESCRIBE financeiro
    cursor.execute("DESCRIBE financeiro")
    financeiro = []
    for row in cursor.fetchall():
        financeiro.append({
            'Field': row[0],
            'Type': row[1],
            'Null': row[2],
            'Key': row[3],
            'Default': row[4],
            'Extra': row[5]
        })
    results['DESCRIBE financeiro'] = financeiro
    
    # 3. DESCRIBE alunos
    cursor.execute("DESCRIBE alunos")
    alunos = []
    for row in cursor.fetchall():
        alunos.append({
            'Field': row[0],
            'Type': row[1],
            'Null': row[2],
            'Key': row[3],
            'Default': row[4],
            'Extra': row[5]
        })
    results['DESCRIBE alunos'] = alunos
    
    # 4. DESCRIBE motoristas
    cursor.execute("DESCRIBE motoristas")
    motoristas = []
    for row in cursor.fetchall():
        motoristas.append({
            'Field': row[0],
            'Type': row[1],
            'Null': row[2],
            'Key': row[3],
            'Default': row[4],
            'Extra': row[5]
        })
    results['DESCRIBE motoristas'] = motoristas
    
    # 5. DESCRIBE responsaveis
    cursor.execute("DESCRIBE responsaveis")
    responsaveis = []
    for row in cursor.fetchall():
        responsaveis.append({
            'Field': row[0],
            'Type': row[1],
            'Null': row[2],
            'Key': row[3],
            'Default': row[4],
            'Extra': row[5]
        })
    results['DESCRIBE responsaveis'] = responsaveis
    
    print(json.dumps(results, indent=2, ensure_ascii=False))
    
    cursor.close()
    conn.close()
    
except Exception as e:
    print(json.dumps({'error': str(e)}, indent=2))

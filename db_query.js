const mysql = require('mysql2/promise');

(async () => {
  try {
    const connection = await mysql.createConnection({
      host: 'localhost',
      user: 'balcao2p_user_eu',
      password: 'Mysql26@',
      database: 'balcao2p_vanpro'
    });

    const results = {};

    // 1. SHOW TABLES
    const [tables] = await connection.query("SHOW TABLES");
    results['SHOW TABLES'] = tables.map(t => Object.values(t)[0]);

    // 2. DESCRIBE financeiro
    const [financeiro] = await connection.query("DESCRIBE financeiro");
    results['DESCRIBE financeiro'] = financeiro;

    // 3. DESCRIBE alunos
    const [alunos] = await connection.query("DESCRIBE alunos");
    results['DESCRIBE alunos'] = alunos;

    // 4. DESCRIBE motoristas
    const [motoristas] = await connection.query("DESCRIBE motoristas");
    results['DESCRIBE motoristas'] = motoristas;

    // 5. DESCRIBE responsaveis
    const [responsaveis] = await connection.query("DESCRIBE responsaveis");
    results['DESCRIBE responsaveis'] = responsaveis;

    console.log(JSON.stringify(results, null, 2));

    await connection.end();
  } catch (error) {
    console.error(JSON.stringify({ error: error.message, code: error.code, errno: error.errno }, null, 2));
    process.exit(1);
  }
})();

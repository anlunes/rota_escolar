-- ============================================================
-- MIGRAÇÃO DE SCHEMA - Rota Escolar
-- Objetivo: Renomear PK 'id' para nomes semânticos em todas as tabelas
-- ATENÇÃO: Faça backup do banco antes de executar!
-- ============================================================

-- ============================================================
-- 1. TABELA: usuarios
-- ============================================================
ALTER TABLE usuarios CHANGE id usuario_id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT;

-- ============================================================
-- 2. TABELA: motoristas
-- ============================================================
-- 2.1 Renomear PK
ALTER TABLE motoristas CHANGE id motorista_id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT;

-- 2.2 Atualizar FK em outras tabelas que referenciam motoristas.id
-- alunos.motorista_id já está correto (nome da coluna já é motorista_id)
-- Verificar se a constraint de FK existe e recriar se necessário

-- ============================================================
-- 3. TABELA: responsaveis
-- ============================================================
-- 3.1 Renomear PK
ALTER TABLE responsaveis CHANGE id responsavel_id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT;

-- 3.2 Atualizar FK em outras tabelas que referenciam responsaveis.id
-- alunos.responsavel_id já está correto (nome da coluna já é responsavel_id)

-- ============================================================
-- 4. TABELA: alunos
-- ============================================================
-- 4.1 Renomear PK
ALTER TABLE alunos CHANGE id aluno_id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT;

-- 4.2 Atualizar FK em outras tabelas que referenciam alunos.id
-- mensalidades.aluno_id já está correto
-- rota_dia_alunos.aluno_id já está correto
-- notificacoes.aluno_id já está correto

-- ============================================================
-- 5. TABELA: avaliacoes
-- ============================================================
-- 5.1 Renomear PK
ALTER TABLE avaliacoes CHANGE id avaliacao_id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT;

-- ============================================================
-- 6. TABELA: mensalidades (já está com id como PK, manter assim)
-- ============================================================
-- A tabela mensalidades já usa 'id' como PK, que é aceitável
-- Não precisa de alteração

-- ============================================================
-- 7. TABELA: escolas (já está com escola_id como PK)
-- ============================================================
-- A tabela escolas já usa 'escola_id' como PK
-- Não precisa de alteração

-- ============================================================
-- 8. TABELA: rota_dias (manter id como PK)
-- ============================================================
-- Tabela de junção, manter 'id' como PK auto-increment

-- ============================================================
-- 9. TABELA: rota_dia_alunos (manter id como PK)
-- ============================================================
-- Tabela de junção, manter 'id' como PK auto-increment

-- ============================================================
-- VERIFICAÇÃO: Descrever tabelas alteradas para confirmar
-- ============================================================
DESCRIBE usuarios;
DESCRIBE motoristas;
DESCRIBE responsaveis;
DESCRIBE alunos;
DESCRIBE avaliacoes;

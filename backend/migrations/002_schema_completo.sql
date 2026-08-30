-- ============================================================
-- Migration 002 - Schema completo Rota Escolar
-- Banco: rotaesc-bd
-- ATENÇÃO: este arquivo reflete o schema original e pode conter
-- definições desatualizadas. Correções aplicadas posteriormente:
--   - usuarios.role: ENUM alterado para ('responsavel','motorista','admin')
--     (era 'guardian','driver','admin') — corrigido via SQL manual em 2026-08-28
--   - escolas: colunas bairro_id, bairro_nome, endereco, cidade, administracao,
--     nivel_escolar removidas; substituídas por bairro, logradouro, numero, municipio
--   - escolas.aprovado + escolas.status: adicionados via migration 003
-- Usar apenas como referência histórica, não para recriar o banco do zero.
-- ============================================================

SET NAMES utf8mb4;
SET foreign_key_checks = 0;

-- ------------------------------------------------------------
-- 1. usuarios - perfil unificado Firebase <-> MySQL
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `usuarios` (
    `id`          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `uid`         VARCHAR(128)    NOT NULL,
    `nome`        VARCHAR(120)    NOT NULL,
    `email`       VARCHAR(180)    NOT NULL,
    `telefone`    VARCHAR(20)     DEFAULT NULL,
    `role`        ENUM('guardian','driver','admin') NOT NULL DEFAULT 'guardian',
    `created_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_usuarios_uid`   (`uid`),
    UNIQUE KEY `uq_usuarios_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 2. motoristas
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `motoristas` (
    `motorista_id` INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    `usuario_id`   INT UNSIGNED   DEFAULT NULL,
    `uid`          VARCHAR(128)   NOT NULL,
    `nome`         VARCHAR(120)   NOT NULL,
    `email`        VARCHAR(180)   NOT NULL,
    `telefone`     VARCHAR(20)    DEFAULT NULL,
    `whatsapp`     VARCHAR(20)    DEFAULT NULL,
    `van_code`     VARCHAR(20)    DEFAULT NULL,
    `foto_url`     VARCHAR(500)   DEFAULT NULL,
    `cnh_url`      VARCHAR(500)   DEFAULT NULL,
    `crlv_url`     VARCHAR(500)   DEFAULT NULL,
    `seguro_url`   VARCHAR(500)   DEFAULT NULL,
    `ativo`        TINYINT(1)     NOT NULL DEFAULT 1,
    `created_at`   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`motorista_id`),
    UNIQUE KEY `uq_motoristas_uid`   (`uid`),
    UNIQUE KEY `uq_motoristas_email` (`email`),
    KEY `idx_motoristas_usuario` (`usuario_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 3. responsaveis
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `responsaveis` (
    `responsavel_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `usuario_id`     INT UNSIGNED DEFAULT NULL,
    `uid`            VARCHAR(128) NOT NULL,
    `nome`           VARCHAR(120) NOT NULL,
    `email`          VARCHAR(180) NOT NULL,
    `telefone`       VARCHAR(20)  DEFAULT NULL,
    `whatsapp`       VARCHAR(20)  DEFAULT NULL,
    `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`responsavel_id`),
    UNIQUE KEY `uq_responsaveis_uid`   (`uid`),
    UNIQUE KEY `uq_responsaveis_email` (`email`),
    KEY `idx_responsaveis_usuario` (`usuario_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 4. estados
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `estados` (
    `id`    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `uf`    CHAR(2)      NOT NULL,
    `nome`  VARCHAR(60)  NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_estados_uf` (`uf`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `estados` (`uf`, `nome`) VALUES
('AC', 'Acre'), ('AL', 'Alagoas'), ('AP', 'Amapá'),
('AM', 'Amazonas'), ('BA', 'Bahia'), ('CE', 'Ceará'),
('DF', 'Distrito Federal'), ('ES', 'Espírito Santo'), ('GO', 'Goiás'),
('MA', 'Maranhão'), ('MT', 'Mato Grosso'), ('MS', 'Mato Grosso do Sul'),
('MG', 'Minas Gerais'), ('PA', 'Pará'), ('PB', 'Paraíba'),
('PR', 'Paraná'), ('PE', 'Pernambuco'), ('PI', 'Piauí'),
('RJ', 'Rio de Janeiro'), ('RN', 'Rio Grande do Norte'),
('RS', 'Rio Grande do Sul'), ('RO', 'Rondônia'), ('RR', 'Roraima'),
('SC', 'Santa Catarina'), ('SP', 'São Paulo'),
('SE', 'Sergipe'), ('TO', 'Tocantins');

-- ------------------------------------------------------------
-- 5. municipios
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `municipios` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `nome`       VARCHAR(100) NOT NULL,
    `estado_id`  INT UNSIGNED NOT NULL,
    `ibge`       VARCHAR(10)  DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_municipios_estado` (`estado_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 6. bairros
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `bairros` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `nome`         VARCHAR(100) NOT NULL,
    `municipio_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_bairros_municipio` (`municipio_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 7. escolas
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `escolas` (
    `escola_id`     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `nome`          VARCHAR(200)  NOT NULL,
    `cidade`        VARCHAR(100)  DEFAULT NULL,
    `municipio`     VARCHAR(100)  DEFAULT NULL,
    `estado`        CHAR(2)       DEFAULT NULL,
    `cep`           VARCHAR(10)   DEFAULT NULL,
    `administracao` VARCHAR(50)   DEFAULT NULL,
    `status`        VARCHAR(30)   DEFAULT NULL,
    `aprovado`      TINYINT(1)    NOT NULL DEFAULT 0,
    `created_at`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`escola_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 8. alunos
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `alunos` (
    `aluno_id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `responsavel_id` INT UNSIGNED NOT NULL,
    `motorista_id`   INT UNSIGNED DEFAULT NULL,
    `escola_id`      INT UNSIGNED DEFAULT NULL,
    `nome`           VARCHAR(120) NOT NULL,
    `ciclo_escolar`  VARCHAR(50)  DEFAULT NULL,
    `cep_residencia` VARCHAR(10)  DEFAULT NULL,
    `endereco`       VARCHAR(255) DEFAULT NULL,
    `van_code`       VARCHAR(20)  DEFAULT NULL,
    `ativo`          TINYINT(1)   NOT NULL DEFAULT 1,
    `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`aluno_id`),
    KEY `idx_alunos_responsavel` (`responsavel_id`),
    KEY `idx_alunos_motorista`   (`motorista_id`),
    KEY `idx_alunos_escola`      (`escola_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 9. motorista_bairros - bairros atendidos pelo motorista
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `motorista_bairros` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `motorista_id` INT UNSIGNED NOT NULL,
    `bairro_id`    INT UNSIGNED NOT NULL,
    `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_mb_motorista_bairro` (`motorista_id`, `bairro_id`),
    KEY `idx_mb_bairro` (`bairro_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 10. escolas_atendidas - escolas atendidas pelo motorista
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `escolas_atendidas` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `motorista_id` INT UNSIGNED NOT NULL,
    `escola_id`    INT UNSIGNED NOT NULL,
    `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_ea_motorista_escola` (`motorista_id`, `escola_id`),
    KEY `idx_ea_escola` (`escola_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 11. rota_templates - rotas padrao do motorista
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rota_templates` (
    `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `motorista_id` INT UNSIGNED NOT NULL,
    `van_code`     VARCHAR(20)  DEFAULT NULL,
    `periodo`      ENUM('manha_ida','manha_volta','tarde_ida','tarde_volta') NOT NULL,
    `nome`         VARCHAR(120) NOT NULL,
    `ativo`        TINYINT(1)   NOT NULL DEFAULT 1,
    `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_rt_motorista` (`motorista_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 12. rota_template_alunos - alunos em cada rota com ordem
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rota_template_alunos` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `rota_template_id` INT UNSIGNED NOT NULL,
    `aluno_id`         INT UNSIGNED NOT NULL,
    `ordem`            INT          NOT NULL DEFAULT 0,
    `ativo`            TINYINT(1)   NOT NULL DEFAULT 1,
    `created_at`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_rta_template_aluno` (`rota_template_id`, `aluno_id`),
    KEY `idx_rta_aluno`    (`aluno_id`),
    KEY `idx_rta_template` (`rota_template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 13. rota_dias - instancia da rota executada no dia
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rota_dias` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `rota_template_id` INT UNSIGNED DEFAULT NULL,
    `motorista_id`     INT UNSIGNED NOT NULL,
    `van_code`         VARCHAR(20)  DEFAULT NULL,
    `periodo`          ENUM('manha_ida','manha_volta','tarde_ida','tarde_volta') NOT NULL,
    `data_servico`     DATE         NOT NULL,
    `status`           ENUM('planejada','em_andamento','concluida','cancelada') NOT NULL DEFAULT 'planejada',
    `created_at`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_rd_motorista_data_periodo` (`motorista_id`, `data_servico`, `periodo`),
    KEY `idx_rd_data`     (`data_servico`),
    KEY `idx_rd_template` (`rota_template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 14. rota_dia_alunos - status de cada aluno no dia
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rota_dia_alunos` (
    `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `rota_dia_id`      INT UNSIGNED NOT NULL,
    `aluno_id`         INT UNSIGNED NOT NULL,
    `ordem`            INT          NOT NULL DEFAULT 0,
    `vai_hoje`         TINYINT(1)   NOT NULL DEFAULT 1,
    `status_atual`     ENUM('waiting_van','to_school','at_school','to_home','at_home') NOT NULL DEFAULT 'waiting_van',
    `talk_requested`   TINYINT(1)   NOT NULL DEFAULT 0,
    `talk_acknowledged`TINYINT(1)   NOT NULL DEFAULT 0,
    `horario_embarque` TIME         DEFAULT NULL,
    `horario_escola`   TIME         DEFAULT NULL,
    `horario_volta`    TIME         DEFAULT NULL,
    `horario_casa`     TIME         DEFAULT NULL,
    `updated_at`       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_rda_rota_aluno` (`rota_dia_id`, `aluno_id`),
    KEY `idx_rda_aluno`  (`aluno_id`),
    KEY `idx_rda_status` (`status_atual`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 15. talk_requests - fila de pedidos de contato
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `talk_requests` (
    `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `aluno_id`        INT UNSIGNED NOT NULL,
    `responsavel_uid` VARCHAR(128) NOT NULL,
    `motorista_id`    INT UNSIGNED NOT NULL,
    `rota_dia_id`     INT UNSIGNED DEFAULT NULL,
    `status`          ENUM('pendente','ciente','resolvido') NOT NULL DEFAULT 'pendente',
    `created_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `acknowledged_at` DATETIME     DEFAULT NULL,
    `resolved_at`     DATETIME     DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_tr_motorista` (`motorista_id`),
    KEY `idx_tr_aluno`     (`aluno_id`),
    KEY `idx_tr_status`    (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 16. avaliacoes
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `avaliacoes` (
    `avaliacao_id`   INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `motorista_id`   INT UNSIGNED  NOT NULL,
    `responsavel_id` INT UNSIGNED  NOT NULL,
    `nota`           TINYINT       NOT NULL COMMENT '1 a 5',
    `comentario`     TEXT          DEFAULT NULL,
    `mes_referencia` VARCHAR(7)    DEFAULT NULL COMMENT 'YYYY-MM',
    `created_at`     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`avaliacao_id`),
    KEY `idx_av_motorista`   (`motorista_id`),
    KEY `idx_av_responsavel` (`responsavel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 17. mensalidades
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mensalidades` (
    `id`              INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `aluno_id`        INT UNSIGNED  NOT NULL,
    `motorista_id`    INT UNSIGNED  NOT NULL,
    `responsavel_id`  INT UNSIGNED  DEFAULT NULL,
    `mes`             TINYINT       NOT NULL COMMENT '1-12',
    `ano`             SMALLINT      NOT NULL,
    `valor`           DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    `status`          ENUM('pendente','pago','atrasado','cancelado') NOT NULL DEFAULT 'pendente',
    `forma_pagamento` VARCHAR(50)   DEFAULT NULL,
    `data_vencimento` DATE          DEFAULT NULL,
    `data_pagamento`  DATE          DEFAULT NULL,
    `observacao`      TEXT          DEFAULT NULL,
    `created_at`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_men_aluno`      (`aluno_id`),
    KEY `idx_men_motorista`  (`motorista_id`),
    KEY `idx_men_responsavel`(`responsavel_id`),
    KEY `idx_men_status`     (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 18. notificacoes
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `notificacoes` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tipo`       VARCHAR(50)  NOT NULL,
    `aluno_id`   INT UNSIGNED DEFAULT NULL,
    `mensagem`   TEXT         NOT NULL,
    `lida`       TINYINT(1)   NOT NULL DEFAULT 0,
    `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_not_aluno` (`aluno_id`),
    KEY `idx_not_lida`  (`lida`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 19. termos_aceite
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `termos_aceite` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `usuario_id`    INT UNSIGNED DEFAULT NULL,
    `uid`           VARCHAR(128) NOT NULL,
    `versao_termos` VARCHAR(20)  NOT NULL DEFAULT '1.0',
    `aceito_em`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ip_origem`     VARCHAR(45)  DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_ta_uid`    (`uid`),
    KEY `idx_ta_versao` (`versao_termos`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET foreign_key_checks = 1;

-- ============================================================
-- END OF MIGRATION 002
-- ============================================================

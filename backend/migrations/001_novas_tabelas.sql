-- ============================================================
-- Migration 001 - Novas tabelas para Rota Escolar
-- Banco: balcao2p_vanpro
-- Execute: mysql -u balcao2p_user_eu -p balcao2p_vanpro < 001_novas_tabelas.sql
-- ============================================================

SET NAMES utf8mb4;
SET foreign_key_checks = 0;

-- ------------------------------------------------------------
-- 1. rota_templates - rotas padrão do motorista
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rota_templates` (
    `id`          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `motorista_id`INT UNSIGNED    NOT NULL,
    `van_code`    VARCHAR(20)     DEFAULT NULL,
    `periodo`     ENUM(
                    'manha_ida',
                    'manha_volta',
                    'tarde_ida',
                    'tarde_volta'
                  )               NOT NULL,
    `nome`        VARCHAR(120)    NOT NULL,
    `ativo`       TINYINT(1)      NOT NULL DEFAULT 1,
    `created_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_rt_motorista` (`motorista_id`),
    KEY `idx_rt_van_code`  (`van_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 2. rota_template_alunos - alunos em cada rota com ordem
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rota_template_alunos` (
    `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `rota_template_id`  INT UNSIGNED NOT NULL,
    `aluno_id`          INT UNSIGNED NOT NULL,
    `ordem`             INT          NOT NULL DEFAULT 0,
    `ativo`             TINYINT(1)   NOT NULL DEFAULT 1,
    `created_at`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_rta_template_aluno` (`rota_template_id`, `aluno_id`),
    KEY `idx_rta_aluno`   (`aluno_id`),
    KEY `idx_rta_template`(`rota_template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 3. rota_dias - instância da rota executada no dia
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rota_dias` (
    `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `rota_template_id`  INT UNSIGNED DEFAULT NULL,
    `motorista_id`      INT UNSIGNED NOT NULL,
    `van_code`          VARCHAR(20)  DEFAULT NULL,
    `periodo`           ENUM(
                          'manha_ida',
                          'manha_volta',
                          'tarde_ida',
                          'tarde_volta'
                        )            NOT NULL,
    `data_servico`      DATE         NOT NULL,
    `status`            ENUM(
                          'planejada',
                          'em_andamento',
                          'concluida',
                          'cancelada'
                        )            NOT NULL DEFAULT 'planejada',
    `created_at`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_rd_motorista_data_periodo` (`motorista_id`, `data_servico`, `periodo`),
    KEY `idx_rd_data`     (`data_servico`),
    KEY `idx_rd_template` (`rota_template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 4. rota_dia_alunos - status de cada aluno no dia
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rota_dia_alunos` (
    `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `rota_dia_id`       INT UNSIGNED NOT NULL,
    `aluno_id`          INT UNSIGNED NOT NULL,
    `ordem`             INT          NOT NULL DEFAULT 0,
    `vai_hoje`          TINYINT(1)   NOT NULL DEFAULT 1,
    `status_atual`      ENUM(
                          'waiting_van',
                          'to_school',
                          'at_school',
                          'to_home',
                          'at_home'
                        )            NOT NULL DEFAULT 'waiting_van',
    `talk_requested`    TINYINT(1)   NOT NULL DEFAULT 0,
    `horario_embarque`  TIME         DEFAULT NULL,
    `horario_escola`    TIME         DEFAULT NULL,
    `horario_volta`     TIME         DEFAULT NULL,
    `horario_casa`      TIME         DEFAULT NULL,
    `updated_at`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_rda_rota_aluno`   (`rota_dia_id`, `aluno_id`),
    KEY `idx_rda_aluno`  (`aluno_id`),
    KEY `idx_rda_status` (`status_atual`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 5. talk_requests - fila "quero falar"
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `talk_requests` (
    `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `aluno_id`          INT UNSIGNED NOT NULL,
    `responsavel_uid`   VARCHAR(128) NOT NULL,
    `motorista_id`      INT UNSIGNED NOT NULL,
    `rota_dia_id`       INT UNSIGNED DEFAULT NULL,
    `status`            ENUM('pendente', 'ciente', 'resolvido') NOT NULL DEFAULT 'pendente',
    `created_at`        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `acknowledged_at`   DATETIME     DEFAULT NULL,
    `resolved_at`       DATETIME     DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_tr_motorista` (`motorista_id`),
    KEY `idx_tr_aluno`     (`aluno_id`),
    KEY `idx_tr_status`    (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 6. bairros_atendidos - motorista atende quais bairros
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `bairros_atendidos` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `motorista_id`  INT UNSIGNED NOT NULL,
    `bairro`        VARCHAR(100) NOT NULL,
    `municipio`     VARCHAR(100) NOT NULL DEFAULT '',
    `estado`        CHAR(2)      NOT NULL DEFAULT 'SP',
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_ba_motorista_bairro` (`motorista_id`, `bairro`, `municipio`),
    KEY `idx_ba_bairro` (`bairro`, `municipio`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 7. escolas_atendidas - motorista atende quais escolas
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `escolas_atendidas` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `motorista_id`  INT UNSIGNED NOT NULL,
    `escola_id`     INT UNSIGNED NOT NULL,
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_ea_motorista_escola` (`motorista_id`, `escola_id`),
    KEY `idx_ea_escola` (`escola_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 8. termos_aceite - registro de aceite dos termos
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `termos_aceite` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `usuario_id`    INT UNSIGNED DEFAULT NULL,
    `uid`           VARCHAR(128) NOT NULL,
    `versao_termos` VARCHAR(20)  NOT NULL DEFAULT '1.0',
    `aceito_em`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ip_origem`     VARCHAR(45)  DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_ta_uid`     (`uid`),
    KEY `idx_ta_versao`  (`versao_termos`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Tabela auxiliar: usuarios (perfil unificado Firebase <-> MySQL)
-- Se já existir, apenas adiciona colunas faltantes.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `usuarios` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `uid`         VARCHAR(128) NOT NULL,
    `name`        VARCHAR(120) NOT NULL,
    `email`       VARCHAR(180) NOT NULL,
    `whatsapp`    VARCHAR(20)  DEFAULT NULL,
    `role`        ENUM('guardian','driver','admin') NOT NULL DEFAULT 'guardian',
    `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_usuarios_uid`   (`uid`),
    UNIQUE KEY `uq_usuarios_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET foreign_key_checks = 1;

-- ============================================================
-- END OF MIGRATION 001
-- ============================================================

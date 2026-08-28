# REFATORAÇÃO: COBERTURA REGIONAL DOS MOTORISTAS

## 1. SQL EXECUTADO (já gerado em migracao_cobertura_regional.sql)

- CREATE TABLE estados, municipios, bairros, motorista_bairros
- ALTER TABLE motoristas (DROP atend_municipio, atend_uf, cpf, docs_verificados, tem_seguro_app, usuario_id)
- SEED estados (27 estados + DF)
- Índices e FKs
- View v_motorista_localizacao

## 2. ARQUIVOS BACKEND IMPACTADOS

### 2.1 Endpoints a ajustar

| Arquivo | Mudança |
|---------|---------|
| `drivers/index.php` | JOIN bairros_atendidos → JOIN motorista_bairros + bairros + municipios |
| `drivers/profile.php` | SELECT bairros_atendidos → SELECT via motorista_bairros + bairros |
| `drivers/profile.php` | SELECT escolas_atendidas → manter (tabela escolas_atendidas continua) |
| `auth/register.php` | Remover inserção de cpf, docs_verificados, tem_seguro_app, usuario_id |
| `upload/foto_cnh.php` | Remover referências a colunas deletadas |
| `upload/foto_crlv.php` | Remover referências a colunas deletadas |

### 2.2 Novos endpoints necessários

| Endpoint | Função |
|----------|--------|
| `GET /api/location/estados.php` | Lista todos os estados |
| `GET /api/location/municipios.php?estado_id=X` | Lista municípios por estado |
| `GET /api/location/bairros.php?municipio_id=X` | Lista bairros por município |
| `POST /api/drivers/bairros.php` | Vincula/desvincula bairros do motorista |
| `GET /api/drivers/bairros.php` | Lista bairros do motorista logado |

## 3. ARQUIVOS FLUTTER IMPACTADOS

### 3.1 Models

- Criar `Estado`, `Municipio`, `Bairro` models
- Atualizar `DriverProfile` model (remover atend_municipio, atend_uf)

### 3.2 Repositories / Services

- `DriverRepository`: ajustar `fetchDrivers()` para novo JOIN
- `DriverRepository`: criar `fetchEstados()`, `fetchMunicipios()`, `fetchBairros()`
- `DriverRepository`: criar `saveBairros(List<int> bairroIds)`

### 3.3 UI

- `DriverProfileTab`: remover campos atend_municipio/atend_uf
- `DriverProfileTab`: adicionar seção "Bairros Atendidos" com multi-select
- Criar widget `BairroSelector` (cascata: Estado → Município → Bairro)

## 4. ESTRATÉGIA FLUTTER: SELEÇÃO DE BAIRROS

```
[DropdownButton] Estado
    ↓ onChanged
[DropdownButton] Município (filtrado por estado_id)
    ↓ onChanged
[MultiSelectChip] Bairros (filtrado por municipio_id)
    ↓ onSelectionChanged
[Botão Salvar] → POST /api/drivers/bairros.php
```

### 4.1 Otimização para performance

- Cachear estados no app (lista pequena, raramente muda)
- Cachear municípios por estado (lazy load)
- Buscar bairros sob demanda (município selecionado)
- Usar `debounce` no campo de busca de bairro

### 4.2 Persistência local (opcional, para offline)

```dart
// Hive boxes
await Hive.openBox<Estado>('estados');
await Hive.openBox<Municipio>('municipios');
await Hive.openBox<Bairro>('bairros');
```

## 5. ENDPOINTS IMPACTADOS: DETALHAMENTO

### 5.1 Cadastro de motorista (`auth/register.php`)

**Antes:**
```php
INSERT INTO motoristas (usuario_id, uid, nome, ..., atend_municipio, atend_uf, ...)
```

**Depois:**
```php
INSERT INTO motoristas (uid, nome, email, telefone, van_code, created_at)
-- bairros são vinculados APÓS cadastro via motorista_bairros
```

### 5.2 Edição de motorista (`drivers/profile.php` PUT)

**Novo campo:** `bairros` (array de IDs)
```php
// DELETE antigos
$pdo->prepare("DELETE FROM motorista_bairros WHERE motorista_id = ?")->execute([$motorista_id]);

// INSERT novos
foreach ($bairros as $bairro_id) {
    $pdo->prepare("INSERT INTO motorista_bairros (motorista_id, bairro_id) VALUES (?, ?)")
        ->execute([$motorista_id, $bairro_id]);
}
```

### 5.3 Busca/filtro (`drivers/index.php`)

**Antes:**
```sql
JOIN bairros_atendidos ba ON ba.motorista_id = m.id
WHERE ba.bairro = ? AND ba.municipio = ?
```

**Depois:**
```sql
JOIN motorista_bairros mb ON mb.motorista_id = m.motorista_id
JOIN bairros b ON b.id = mb.bairro_id
JOIN municipios mu ON mu.id = b.municipio_id
WHERE b.nome = ? AND mu.nome = ?
```

### 5.4 Listagem do motorista logado

**Antes:**
```sql
SELECT atend_municipio, atend_uf FROM motoristas WHERE uid = ?
```

**Depois:**
```sql
SELECT b.nome AS bairro, mu.nome AS municipio, e.uf
FROM motorista_bairros mb
JOIN bairros b ON b.id = mb.bairro_id
JOIN municipios mu ON mu.id = b.municipio_id
JOIN estados e ON e.id = mu.estado_id
WHERE mb.motorista_id = ?
```

## 6. DTOs / SERIALIZERS

### 6.1 Novo DTO: MotoristaLocalizacaoDTO

```php
class MotoristaLocalizacaoDTO {
    public int $motorista_id;
    public string $nome;
    public array $bairros;      // [{id, nome, municipio, uf}]
    public array $municipios;   // [{id, nome, uf}]
    public array $ufs;          // ['RJ', 'SP']
}
```

### 6.2 Novo DTO: BairroDTO

```php
class BairroDTO {
    public int $id;
    public string $nome;
    public int $municipio_id;
    public string $municipio_nome;
    public string $uf;
}
```

## 7. PERFORMANCE E ESCALABILIDADE

### 7.1 Índices críticos

```sql
-- Busca de motoristas por bairro (filtro principal)
CREATE INDEX idx_mb_bairro_motorista ON motorista_bairros(bairro_id, motorista_id);

-- Listagem de bairros por motorista (perfil)
CREATE INDEX idx_mb_motorista_bairro ON motorista_bairros(motorista_id, bairro_id);

-- Dropdown de bairros por município
CREATE INDEX idx_bairros_municipio_nome ON bairros(municipio_id, nome);
```

### 7.2 Cache de leitura

- Estados: cache permanente (27 registros)
- Municípios: cache por estado (TTL 1 dia)
- Bairros: cache por município (TTL 1 hora)

### 7.3 Paginação

```sql
-- Listar motoristas por bairro com paginação
SELECT m.motorista_id, m.nome, m.van_code, m.foto_url
FROM motoristas m
JOIN motorista_bairros mb ON mb.motorista_id = m.motorista_id
WHERE mb.bairro_id = ? AND m.ativo = 1
ORDER BY m.avaliacao_media DESC
LIMIT ? OFFSET ?;
```

## 8. FUTURO: GEOLOCALIZAÇÃO

### 8.1 Extensão planejada (não implementar agora)

```sql
-- Adicionar à tabela bairros no futuro
ALTER TABLE bairros ADD COLUMN centro_lat DECIMAL(10,7) NULL;
ALTER TABLE bairros ADD COLUMN centro_lng DECIMAL(10,7) NULL;
ALTER TABLE bairros ADD COLUMN raio_km DECIMAL(5,2) NULL DEFAULT 2.00;

-- Índice espacial (MySQL 5.7+ ou 8.0)
ALTER TABLE bairros ADD COLUMN centro POINT NULL;
CREATE SPATIAL INDEX idx_bairros_centro ON bairros(centro);
```

### 8.2 Query futura: motoristas próximos

```sql
-- MySQL 8.0 com ST_Distance_Sphere
SELECT m.motorista_id, m.nome,
       ST_Distance_Sphere(b.centro, POINT(?, ?)) AS distancia_metros
FROM motoristas m
JOIN motorista_bairros mb ON mb.motorista_id = m.motorista_id
JOIN bairros b ON b.id = mb.bairro_id
WHERE ST_Distance_Sphere(b.centro, POINT(?, ?)) <= 5000  -- 5km
AND m.ativo = 1
ORDER BY distancia_metros;
```

## 9. CHECKLIST DE IMPLEMENTAÇÃO

### Fase 1: Banco (1-2 horas)
- [ ] Executar SQL de criação de tabelas
- [ ] Executar ALTER TABLE motoristas
- [ ] Popular estados
- [ ] Migrar dados existentes (se houver)
- [ ] Criar índices

### Fase 2: Backend (3-4 horas)
- [ ] Criar endpoints de localização (estados, municípios, bairros)
- [ ] Ajustar drivers/index.php
- [ ] Ajustar drivers/profile.php
- [ ] Criar endpoint POST/GET motorista_bairros
- [ ] Ajustar auth/register.php
- [ ] Testar endpoints

### Fase 3: Flutter (4-6 horas)
- [ ] Criar models Estado, Municipio, Bairro
- [ ] Criar repositories de localização
- [ ] Criar widget BairroSelector
- [ ] Ajustar DriverProfileTab
- [ ] Ajustar filtros de busca
- [ ] Testar fluxo completo

### Fase 4: Deploy (1 hora)
- [ ] Deploy backend
- [ ] Build Flutter
- [ ] Teste em produção
- [ ] Monitorar logs

## 10. ARQUIVOS A CRIAR

### Backend
```
api/location/
  estados.php
  municipios.php
  bairros.php
api/drivers/
  bairros.php       # GET/POST vinculação de bairros
```

### Flutter
```
lib/features/location/
  domain/
    models/
      estado.dart
      municipio.dart
      bairro.dart
  data/
    location_repository.dart
  presentation/
    widgets/
      bairro_selector.dart
```

## 11. DECISÕES TOMADAS

1. **Não usar tabela `bairros_atendidos` antiga** → migrar para `motorista_bairros`
2. **Manter `escolas_atendidas`** → não impacta esta refatoração
3. **UID do Firebase como identificador externo** → `motorista_id` continua PK interna
4. **Foto obrigatória no cadastro** → validação no Flutter + backend
5. **CNH e CRLV obrigatórios** → validação no Flutter + backend
6. **Não implementar geolocalização agora** → estrutura preparada para futuro

---

**Próximo passo:** Quer que eu gere os arquivos backend (endpoints de localização) ou prefere começar pelo Flutter?

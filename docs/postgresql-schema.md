# PostgreSQL Schema

Ver `docs/architecture-plan.md` seção 5 para o schema SQL completo.

## Tabelas Principais

### Core
- `users` - Usuários do sistema (Firebase UID)
- `guardians` - Responsáveis
- `drivers` - Motoristas
- `vans` - Vans (com VanCode)

### Operacional
- `students` - Alunos
- `guardian_students` - Vínculo responsável ↔ aluno
- `schools` - Escolas (com aprovação)
- `cities` - Cidades
- `addresses` - Endereços

### Rotas
- `route_templates` - Templates de rota
- `route_template_stops` - Paradas do template
- `route_days` - Instância da rota do dia
- `route_day_students` - Alunos na rota do dia

### Auditoria
- `student_status_logs` - Logs de mudança de status
- `talk_requests` - Solicitações de conversa

## Migrations

As migrations devem ser criadas em ordem sequencial:

1. `001_create_core_tables.sql` - users, guardians, drivers, vans
2. `002_create_location_tables.sql` - cities, addresses
3. `003_create_schools.sql` - schools
4. `004_create_students.sql` - students, guardian_students
5. `005_create_routes.sql` - route_templates, route_days, etc
6. `006_create_logs.sql` - student_status_logs, talk_requests

## Seeds Iniciais

- 10 cidades base (São Paulo, Rio, Brasília, etc.)
- 5 escolas aprovadas para teste
- 1 van de teste com VanCode conhecido

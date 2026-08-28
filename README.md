# Rota Escolar

App de transporte escolar inteligente para motoristas e pais de alunos.

## Stack

- **Flutter** (Android + iOS)
- **Firebase**: Auth, Realtime Database, Cloud Messaging
- **Backend**: Node.js + PostgreSQL
- **State Management**: Riverpod
- **Routing**: GoRouter

## Identidade Visual

- Amarelo (#FFD700 range) - Cor primária (van escolar)
- Branco - Background
- Preto - Texto e contraste

## Estrutura do Projeto

```
lib/
  app/              # Configuração global, tema, router
  shared/           # Código compartilhado entre features
  features/         # Features organizadas por domínio
    auth/
    guardian_home/
    driver_home/
    students/
    routes/
    realtime_status/
    chat_flags/
    profile/
    notifications/
```

## Documentação

- [Arquitetura Completa](docs/architecture-plan.md)
- [Firebase Schema](docs/firebase-schema.md)
- [PostgreSQL Schema](docs/postgresql-schema.md)

## Setup

### 1. Instalar dependências

```bash
flutter pub get
```

### 2. Configurar Firebase

1. Criar projeto Firebase
2. Adicionar app Android e iOS
3. Baixar arquivos de configuração
4. Habilitar Auth, Realtime Database e FCM

### 3. Configurar Backend

Ver `docs/architecture-plan.md` para estrutura do backend Node.js.

### 4. Rodar o app

```bash
flutter run
```

## Features MVP (Fase 1)

1. ✅ Setup inicial e estrutura
2. 🔜 Autenticação (Firebase Auth)
3. 🔜 Home Responsável (cards dos alunos com status)
4. 🔜 Home Motorista (lista da rota, drag-and-drop)
5. 🔜 Sincronização tempo real (Firebase Realtime)
6. 🔜 Cadastro de aluno
7. 🔜 Link WhatsApp
8. 🔜 Gerenciamento de rotas do dia

## Status do Projeto

**Fase atual**: Setup inicial concluído ✅

**Próximos passos**:
- Configurar Firebase
- Implementar feature `auth`
- Criar backend Node.js básico
- Preparar PostgreSQL

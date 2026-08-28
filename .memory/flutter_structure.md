Adicione apenas informações novas descobertas sobre:
- módulo de motoristas
- perfil do motorista
- fluxo de salvamento

adicione somente o necessário
patch mínimo
preserve conteúdo existente

Não reescrever arquivo inteiro.
Patch mínimo

# Flutter Structure

## Frontend Stack

- Flutter Web
- Riverpod
- Responsive layout

---

# Folder Structure

lib/
├── core/
├── features/
├── services/
├── widgets/
├── models/

---

# Feature Pattern

Each feature should contain:

- presentation/
- controllers/
- services/
- models/

---

# State Management Rules

- Riverpod only
- Avoid introducing new state systems
- Keep state localized when possible

---

# Navigation Rules

- Preserve existing route structure
- Avoid renaming routes
- Avoid unnecessary navigation rewrites

---

# UI Rules

- Prefer minimal UI changes
- Avoid restructuring stable screens
- Maintain responsive behavior

---

# Performance Rules

- Avoid unnecessary rebuilds
- Avoid excessive global state
- Prefer isolated widget updates

---

# Agent Restrictions

- Do not refactor stable modules
- Avoid creating unnecessary files
- Prefer minimal patches
- Avoid broad architecture rewrites

---

# Main Modules

| Module | Description |
|--------|-------------|
| auth | Login, register |
| driver_home | Driver main page |
| guardian_home | Guardian main page |
| students | Student management |
| routes | School routes |
| evaluation | Assessments |
| location | GPS location |
| notifications | Push notifications |
| profile | User profile |
| realtime_status | Real-time status |
| onboarding | Initial tutorial |
| chat_flags | Chat flags |
| faq | FAQ |

---

# Architecture

Feature-based pattern:
- Each feature in lib/features/
- Structure: presentation/ + application/ + data/ + domain/
- Shared utilities in lib/shared/
- Core app config in lib/app/

---

# Driver Module (lib/features/driver_home)

- Pages: driver_home_page.dart
- Tabs: financial, messages, opportunities, profile, route
- Provider: driver_home_provider.dart
- Repository: driver_repository.dart
- Endpoints: /api/drivers/*

---

# Guardian Module (lib/features/guardian_home)

- Pages: guardian_home_page.dart (single page, no tabs)
- Provider: guardian_home_provider.dart
- Repository: students_repository.dart
- Endpoints: /api/students/*

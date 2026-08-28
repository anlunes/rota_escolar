# Architecture Overview

## Project Structure

This project consists of:

- Flutter Web frontend
- PHP API backend
- MySQL database
- Firebase integrations

---

# Frontend Architecture

## State Management

- Riverpod is mandatory
- Avoid introducing alternative state managers

## Navigation

- Existing route structure must be preserved
- Do not rename stable routes

## UI Structure

Frontend organized by feature modules:

lib/
├── features/
├── core/
├── services/
├── widgets/
├── models/

## Feature Pattern

Each feature should contain:

- presentation/
- controllers/
- services/
- models/

---

# Backend Architecture

## API Structure

- REST-style PHP API
- Existing endpoints are stable
- Preserve response formats

## Database

- MySQL
- Avoid schema changes unless explicitly requested

## Authentication

- Existing authentication flow is considered stable
- Do not modify auth logic without authorization

---

# Stability Rules

## Stable Modules

These modules should not be refactored:

- Authentication
- Route registration
- Financial dashboard

## Allowed Changes

- Localized bug fixes
- Feature additions inside isolated modules
- UI adjustments

## Forbidden Behaviors

- Large-scale refactors
- Renaming stable classes
- Moving files unnecessarily
- Reorganizing folders without permission

---

# Agent Operational Rules

Before making changes:

1. Identify impacted files
2. Explain intended modification briefly
3. Apply minimal patch
4. Avoid touching unrelated code

---

# Known Technical Debt

- Legacy state logic inside driver profile
- Notification synchronization instability
- Some duplicated services pending cleanup
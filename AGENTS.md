# Global Agent Rules

## Core Rules

- Never refactor stable modules unless explicitly requested
- Work on one feature at a time
- Never modify unrelated files
- Prefer minimal patches
- Avoid architecture rewrites
- Never rename stable classes/files
- Never change API contracts without permission

## Flutter Rules

- Use Riverpod only
- Preserve existing navigation structure
- Avoid unnecessary widget extraction
- Keep UI logic separated from services

## Backend Rules

- Preserve existing API routes
- Avoid changing response formats
- Keep compatibility with current frontend

## Workflow Rules

- First analyze impacted files
- Then propose a concise plan
- Then execute changes
- Never perform hidden modifications

## Token Economy Rules

- Keep responses concise
- Avoid re-scanning the whole project repeatedly
- Use existing documentation files first
- Prefer targeted searches
# Database Schema

## drivers

Fields:
- id
- name
- route_id
- status

## users

Fields:
- id
- email
- password_hash
- role

## notifications

Fields:
- id
- user_id
- message
- created_at

## Restrictions

- Avoid schema changes
- Preserve existing relations
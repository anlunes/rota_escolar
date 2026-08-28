# Deployment

## Frontend

Build command:

flutter build web --release

Deploy command:

scp -r build/web/* server:path

---

## Backend

Deploy:
- Upload API files via SCP

Restrictions:
- Do not modify production environment configs automatically
- Never overwrite .env without permission
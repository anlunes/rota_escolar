# Authentication Flow

## Frontend

1. User submits login form
2. Frontend sends credentials to API
3. API validates credentials
4. JWT/session returned
5. Session persisted locally

## Restrictions

* Authentication flow is stable
* Do not modify token structure
* Do not alter login endpoint behavior

## Related Files

Frontend:

* auth_service.dart
* login_page.dart

Backend:

* /api/auth/login.php

## Flutter → Firebase → API PHP

### 1. Login (Flutter)
- User enters email + password
- AuthRepository.login() calls Firebase Auth

### 2. Firebase Auth
- Validates credentials
- Returns Firebase token

### 3. Profile Request (Flutter)
- GET /api/auth/profile.php
- Header: Authorization: Bearer {token}

### 4. Middleware Validation (PHP)
- auth_middleware.php validates Bearer token
- Extracts user ID from token

### 5. Response
- API returns user profile data
- Flutter updates AuthState

---

## Files Involved

| Layer | File |
|-------|------|
| Flutter UI | login_page.dart |
| Flutter State | auth_state_provider.dart |
| Flutter Repo | auth_repository.dart |
| Firebase Config | firebase_options.dart |
| PHP Endpoint | backend/api/auth/profile.php |
| PHP Middleware | backend/middleware/auth_middleware.php |

## Role-Based Routing

After authentication, the user role determines navigation:

- **Driver** → Driver dashboard (routes, trips, students)
- **Guardian** → Guardian dashboard (children, pickup locations, notifications)

Role is retrieved from `/api/auth/profile.php` response and stored in AuthState.
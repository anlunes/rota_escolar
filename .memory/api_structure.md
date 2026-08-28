# API Structure

## Backend Stack

- PHP API
- MySQL database
- REST-style endpoints

---

# Authentication Endpoints

POST /auth/login
POST /auth/logout
GET /auth/session

Notes:
- Response format is stable
- Do not modify token structure

---

# Driver Endpoints

GET /drivers
GET /drivers/{id}
POST /drivers/create
PUT /drivers/update

Notes:
- Existing frontend depends on current response shape

---

# Financial Endpoints

GET /financial/dashboard
GET /financial/reports

Notes:
- Preserve existing numeric formats

---

# Notification Endpoints

GET /notifications
POST /notifications/read

Known Issues:
- Delayed synchronization possible

---

# API Modules

| Module | Endpoints |
|--------|-----------|
| auth | profile.php, register.php |
| students | index.php, update.php |
| routes | index.php, reorder.php |
| drivers | index.php, profile.php, bairros.php |
| schools | index.php, create.php |
| evaluations | index.php, create.php |
| financial | index.php, pay.php, notify.php |
| location | estados.php, municipios.php, bairros.php |
| upload | foto_cnh.php, foto_crlv.php |

---

# Auth/Profile Flow

1. Flutter → Firebase Auth (login)
2. Firebase → returns token
3. Flutter → GET /api/auth/profile.php (Bearer token)
4. auth_middleware.php validates token
5. Returns user profile data

---

# Drivers/Bairros

- GET /api/drivers/bairros.php - Get neighborhoods for driver
- Requires Bearer token authentication
- Returns list of neighborhoods assigned to driver

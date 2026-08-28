# Firebase Realtime Database Schema

## Estrutura JSON Completa

```json
{
  "vans": {
    "{vanId}": {
      "activeRouteDayId": "route_day_123",
      "driverId": "uid_driver_1",
      "status": "online",
      "updatedAt": 1710000000
    }
  },
  
  "routeDays": {
    "{routeDayId}": {
      "vanId": "van_1",
      "period": "morning_outbound",
      "date": "2026-05-12",
      "driverId": "uid_driver_1",
      "studentOrder": {
        "student_1": 1,
        "student_2": 2,
        "student_3": 3
      },
      "students": {
        "student_1": {
          "status": "waiting_van",
          "goToday": true,
          "talkRequested": false,
          "lastStatusAt": 1710000000,
          "lastUpdatedBy": "uid_driver_1"
        }
      }
    }
  },
  
  "studentsRealtime": {
    "{studentId}": {
      "currentRouteDayId": "route_day_123",
      "currentStatus": "to_school",
      "goToday": true,
      "talkRequested": false,
      "guardianIds": {
        "uid_guardian_1": true
      },
      "driverId": "uid_driver_1",
      "vanId": "van_1",
      "updatedAt": 1710000100
    }
  },
  
  "talkRequests": {
    "{driverId}": {
      "{studentId}": {
        "guardianId": "uid_guardian_1",
        "messageType": "talk_request",
        "status": "pending",
        "createdAt": 1710000000,
        "ackAt": null
      }
    }
  },
  
  "presence": {
    "drivers": {
      "{driverId}": {
        "online": true,
        "lastSeenAt": 1710000000
      }
    }
  },
  
  "notificationsQueue": {
    "{eventId}": {
      "type": "student_status_changed",
      "targetUserIds": {
        "uid_guardian_1": true
      },
      "payload": {
        "studentId": "student_1",
        "status": "at_school"
      },
      "createdAt": 1710000000,
      "processed": false
    }
  }
}
```

## Status Values

- `waiting_van` - Aguardando van
- `to_school` - A caminho da escola
- `at_school` - Na escola
- `to_home` - A caminho de casa
- `at_home` - Em casa

## Period Values

- `morning_outbound` - Manhã ida escola
- `morning_return` - Manhã volta casa
- `afternoon_outbound` - Tarde ida escola
- `afternoon_return` - Tarde volta casa

## Security Rules (a implementar)

### Leitura
- Responsável: apenas nós de seus filhos
- Motorista: apenas nós de sua van/rota ativa
- Admin: acesso total

### Escrita
- Responsável: apenas `goToday` e `talkRequested` de seus filhos
- Motorista: apenas `status` dos alunos de sua rota
- Backend/Admin: acesso total

# Known Bugs

## Driver Profile

Issue:
- Duplicate state updates occasionally occur

Possible Cause:
- Legacy state management mixed with Riverpod

Current Status:
- Under investigation

Restrictions:
- Avoid full refactor
- Apply minimal fixes only

---

## Notification Sync

Issue:
- Some notifications arrive delayed

Possible Cause:
- Firebase synchronization timing

Current Status:
- Non-critical

---

## Flutter Web Layout

Issue:
- Sidebar occasionally overlaps content on smaller screens

Current Status:
- Pending UI stabilization

---

## Technical Debt

### Legacy State Logic
Location: Driver profile module
Issue: Mixed legacy state management with Riverpod
Impact: Occasional duplicate state updates

### Notification Sync Instability
Issue: Delayed notification delivery
Cause: Firebase synchronization timing

### Duplicated Services
Location: Various modules
Issue: Some services pending cleanup
Status: Low priority

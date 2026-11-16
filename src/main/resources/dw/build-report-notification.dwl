%dw 2.0
output application/json

var s = payload.statistics
---
[
    payload.period.startDate ++ " a " ++ payload.period.endDate,
    s.totalEmails as String,
    s.categories.URGENTE as String,
    s.importantEmails as String,
    s.unreadEmails as String,
    s.pendingActions as String
]

%dw 2.0
output application/json

fun clip(value, size: Number): String =
    do {
        var text = (value default "") as String
        ---
        if (sizeOf(text) > size) text[0 to (size - 1)] else text
    }

---
[
    clip(payload.sender_name default payload.sender_email, 120),
    clip(payload.subject, 200),
    payload.urgency_level,
    (payload.received_at as DateTime) as String {format: "dd/MM/yyyy HH:mm", timezone: p('report.timezone')},
    clip(payload.classification_reason, 300),
    p('security.adminDashboardUrl')
]

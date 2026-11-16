%dw 2.0
output application/json

var rows = payload
var limit = vars.notificationFilters.limit default 20
---
{
    items: rows map ((row) -> {
        id: row.id as String,
        emailId: row.email_id as String,
        channel: row.channel,
        status: row.status,
        templateName: row.template_name,
        providerMessageId: row.provider_message_id,
        lastErrorCode: row.last_error_code,
        createdAt: row.created_at,
        sentAt: row.sent_at
    }),
    nextCursor: if (sizeOf(rows) >= limit and not isEmpty(rows)) rows[sizeOf(rows) - 1].created_at else null
}

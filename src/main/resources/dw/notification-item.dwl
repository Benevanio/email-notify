%dw 2.0
output application/json

var row = payload[0]
---
{
    id: row.id as String,
    emailId: row.email_id as String,
    channel: row.channel,
    status: row.status,
    templateName: row.template_name,
    providerMessageId: row.provider_message_id,
    lastErrorCode: row.last_error_code,
    createdAt: row.created_at,
    sentAt: row.sent_at
}

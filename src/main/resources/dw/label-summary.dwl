%dw 2.0
output application/json

/**
 * Resumo de uma label (labels.get). Somente leitura.
 */
---
{
    id: payload.id,
    name: payload.name,
    type: payload.type default "user",
    messagesTotal: payload.messagesTotal default 0,
    messagesUnread: payload.messagesUnread default 0,
    threadsTotal: payload.threadsTotal default 0,
    threadsUnread: payload.threadsUnread default 0
}

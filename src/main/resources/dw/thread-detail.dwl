%dw 2.0
output application/json
import * from messageNormalizer

/**
 * Conversa (threads.get com format=metadata): mensagens normalizadas, em ordem cronológica, sem corpo.
 */
var messages = (payload.messages default []) map ((msg) -> normalizeMessage(msg))
---
{
    id: payload.id,
    historyId: payload.historyId,
    messageCount: sizeOf(messages),
    messages: messages orderBy ((m) -> m.receivedAt default "")
}

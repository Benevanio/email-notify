%dw 2.0
output application/json
import * from messageNormalizer

/**
 * Normaliza uma mensagem bruta (messages.get) ou uma lista delas.
 */
---
if (payload is Array) payload map ((msg) -> normalizeMessage(msg))
else normalizeMessage(payload)

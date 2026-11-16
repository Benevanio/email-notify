%dw 2.0
output application/json
import * from messageNormalizer
import * from mimeDecoder

/**
 * Detalhe de uma mensagem (format=full): dados normalizados + corpo em texto plano, truncado.
 */
var maxChars = p('gmail.maxBodyCharacters') as Number
var fullBody = plainTextBody(payload.payload default {})
var truncated = sizeOf(fullBody) > maxChars
---
normalizeMessage(payload) mergeWith {
    body: if (truncated) fullBody[0 to (maxChars - 1)] else fullBody,
    bodyTruncated: truncated
}

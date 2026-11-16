%dw 2.0
output application/json

fun clip(value, size: Number): String | Null =
    if (value == null) null
    else do {
        var text = value as String
        ---
        if (sizeOf(text) > size) text[0 to (size - 1)] else text
    }

var c = payload.classification
---
{
    gmailMessageId: payload.id,
    gmailThreadId: payload.threadId,
    senderEmail: clip(payload.senderEmail, 320),
    senderDomain: clip(payload.senderDomain, 255),
    senderName: clip(payload.senderName, 255),
    subject: clip(payload.subject, 998),
    snippet: clip(payload.snippet, 500),
    receivedAt: payload.receivedAt default (now() as String),
    isUnread: payload.unread,
    labelIds: write(payload.labelIds default [], "application/json"),
    category: c.category,
    urgencyLevel: c.urgencyLevel,
    requiresAction: c.requiresAction,
    possibleAction: c.possibleAction,
    classificationReason: c.classificationReason,
    classifierVersion: c.classifierVersion
}

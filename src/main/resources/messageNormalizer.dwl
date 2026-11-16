%dw 2.0
import * from emailClassifier
import * from mimeDecoder
import * from dw::core::Objects

fun extractEmail(fromRaw: String): String =
    do {
        var bracketed = fromRaw match /<([^>]+)>/
        var address = if (isEmpty(bracketed)) fromRaw else bracketed[1]
        ---
        lower(trim(address))
    }

fun senderNameOf(fromRaw: String): String | Null =
    if (fromRaw contains "<") (trim((fromRaw splitBy "<")[0]) replace "\"" with "") else null

fun domainOf(email: String): String =
    if (email contains "@") (email splitBy "@")[1] else ""

fun receivedAtOf(msg): DateTime | Null =
    do {
        var parsed = try(() -> ((msg.internalDate as Number) as DateTime {unit: "milliseconds"}))
        ---
        if (parsed.success) parsed.result else null
    }

fun normalizeMessage(msg): Object =
    do {
        var tz = p('report.timezone')
        var receivedAt = receivedAtOf(msg)
        var fromRaw = headerValue(msg, "From") default ""
        var email = extractEmail(fromRaw)
        var base = {
            id: msg.id,
            threadId: msg.threadId,
            labelIds: msg.labelIds default [],
            unread: (msg.labelIds default []) contains "UNREAD",
            from: fromRaw,
            senderEmail: email,
            senderDomain: domainOf(email),
            senderName: senderNameOf(fromRaw),
            to: headerValue(msg, "To") default "",
            cc: headerValue(msg, "Cc") default "",
            subject: headerValue(msg, "Subject") default "(Sem assunto)",
            dateHeader: headerValue(msg, "Date"),
            snippet: msg.snippet default "",
            receivedAt: if (receivedAt == null) null else (receivedAt as String),
            localDate: if (receivedAt == null) null else (receivedAt as String {format: "yyyy-MM-dd", timezone: tz})
        }
        ---
        base mergeWith {classification: triage(base)}
    }

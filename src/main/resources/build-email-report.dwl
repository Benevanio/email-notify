
%dw 2.0
output application/json
import * from dw::core::Arrays
import * from dw::core::Strings

var emails = payload.emails default []
var request = payload.reportRequest default {}

var startDate = request.startDate default null
var endDate = request.endDate default null

var includeRead = request.includeRead default true
var includeUnread = request.includeUnread default true
var groupBy = request.groupBy default "day"

var filteredEmails =
    emails filter ((email) ->
        (includeRead and not (email.unread default false))
        or
        (includeUnread and (email.unread default false))
    )

var normalizedEmails =
    filteredEmails map ((email) -> {
        id: email.id default "",
        threadId: email.threadId default "",
        from: email.from default "Unknown",
        subject: email.subject default "(Sem assunto)",
        snippet: email.snippet default "",
        date: email.date default null,
        unread: email.unread default false,
        labels: email.labels default [],
        body: email.body default ""
    })

var senders =
    normalizedEmails groupBy ((email) -> lower(email.from))

var frequentSenders =
    senders pluck ((messages, sender) -> {
        email: sender,
        totalEmails: sizeOf(messages)
    })
    orderBy ((sender) -> -sender.totalEmails)

var dateKey = (email) ->
    if (email.date == null)
        "unknown"
    else do {
        var date = (email.date as DateTime)
        ---
        if (groupBy == "month")
            date as String {format: "yyyy-MM"}
        else if (groupBy == "week")
            date as String {format: "YYYY-'W'ww"}
        else
            date as String {format: "yyyy-MM-dd"}
    }

var groupedByDate =
    normalizedEmails groupBy dateKey

var dailyVolume =
    groupedByDate pluck ((messages, period) -> {
        period: period,
        totalEmails: sizeOf(messages),
        unreadEmails: sizeOf(
            messages filter ((email) -> email.unread)
        )
    })
    orderBy ((item) -> item.period)

var importantEmails =
    normalizedEmails
        filter ((email) ->
            email.unread
            or
            (
                (email.subject ++ " " ++ email.snippet)
                    matches /(?i).*(urgente|urgent|prazo|deadline|aprovação|approval|importante|important).*/
            )
        )
        map ((email) -> {
            emailId: email.id,
            subject: email.subject,
            from: email.from,
            date: email.date,
            reason:
                if (email.unread)
                    "Mensagem ainda não lida."
                else
                    "Assunto ou conteúdo contém termos de prioridade.",
            priority:
                if (
                    (email.subject ++ " " ++ email.snippet)
                        matches /(?i).*(urgente|urgent|imediato|immediate|critical).*/
                )
                    "CRITICAL"
                else if (
                    (email.subject ++ " " ++ email.snippet)
                        matches /(?i).*(prazo|deadline|aprovação|approval|importante|important).*/
                )
                    "HIGH"
                else
                    "MEDIUM"
        })

var pendingActions =
    normalizedEmails
        filter ((email) ->
            (email.subject ++ " " ++ email.snippet)
                matches /(?i).*(preciso|favor|solicito|aguardo|responder|retornar|enviar|confirmar|pendente|aprovar|please|awaiting|reply|respond|confirm|pending).*/
        )
        map ((email) -> {
            emailId: email.id,
            subject: email.subject,
            description: email.snippet,
            priority:
                if (email.unread)
                    "HIGH"
                else
                    "MEDIUM"
        })

var readCount =
    sizeOf(normalizedEmails filter ((email) -> not email.unread))

var unreadCount =
    sizeOf(normalizedEmails filter ((email) -> email.unread))

var uniqueSenders =
    sizeOf(senders)

---
{
    reportId: uuid(),
    generatedAt: now() as String,
    period: {
        startDate: startDate,
        endDate: endDate
    },
    filters: {
        includeRead: includeRead,
        includeUnread: includeUnread,
        groupBy: groupBy
    },
    statistics: {
        totalEmails: sizeOf(normalizedEmails),
        readEmails: readCount,
        unreadEmails: unreadCount,
        uniqueSenders: uniqueSenders,
        pendingActions: sizeOf(pendingActions),
        importantEmails: sizeOf(importantEmails)
    },
    importantEmails: importantEmails,
    pendingActions: pendingActions,
    frequentSenders: frequentSenders,
    dailyVolume: dailyVolume,
    executiveSummary:
        "Foram analisados "
        ++ (sizeOf(normalizedEmails) as String)
        ++ " e-mails. "
        ++ (unreadCount as String)
        ++ " mensagens estão não lidas, "
        ++ (sizeOf(importantEmails) as String)
        ++ " foram classificadas como importantes e "
        ++ (sizeOf(pendingActions) as String)
        ++ " apresentam possíveis ações pendentes."
}

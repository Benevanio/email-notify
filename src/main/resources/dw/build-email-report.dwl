%dw 2.0
output application/json

/**
 * Constrói o relatório consolidado de e-mails.
 *
 * Entrada (payload):
 *   request:    { startDate, endDate, groupBy, includeRead, includeUnread, maxEmails, query }  (datas yyyy-MM-dd, validadas)
 *   messages:   [ mensagens normalizadas pelo messageNormalizer ]
 *   collection: { truncated: Boolean }
 *
 * Os filtros de data e de leitura são aplicados aqui, de fato, antes de qualquer agregação.
 * Não há corpos de e-mail na saída. Classificações são heurísticas.
 */

var req = payload.request
var tz = p('report.timezone')
var grouping = req.groupBy default "day"
var includeRead = req.includeRead default true
var includeUnread = req.includeUnread default true
var startDate = req.startDate
var endDate = req.endDate
var allMessages = payload.messages default []

fun isInPeriod(m): Boolean =
    if (m.localDate == null) false
    else (m.localDate >= startDate and m.localDate <= endDate)

fun isSelectedReadState(m): Boolean =
    (includeRead and not (m.unread default false)) or (includeUnread and (m.unread default false))

fun periodOf(m): String =
    if (grouping == "month")
        ((m.localDate splitBy "-")[0]) ++ "-" ++ ((m.localDate splitBy "-")[1])
    else if (grouping == "week")
        ((m.receivedAt as DateTime) as String {format: "YYYY-'W'ww", timezone: tz})
    else m.localDate

var skippedInvalidDates = sizeOf(allMessages filter ((m) -> m.localDate == null))
var analyzed = allMessages filter ((m) -> isInPeriod(m) and isSelectedReadState(m))

var senderStats = (analyzed groupBy ((m) -> m.senderEmail)) pluck ((items, sender) -> {
    sender: sender,
    totalEmails: sizeOf(items),
    unreadEmails: sizeOf(items filter ((m) -> m.unread))
})

var frequentSenders =
    (senderStats orderBy ((s) -> 0 - s.totalEmails))
        filter ((s, index) -> index < 20)

var volume = (analyzed groupBy ((m) -> periodOf(m))) pluck ((items, period) -> {
    period: period,
    totalEmails: sizeOf(items),
    unreadEmails: sizeOf(items filter ((m) -> m.unread))
}) orderBy ((v) -> v.period)

var importantEmails = analyzed
    filter ((m) -> m.priority == "CRITICAL" or m.priority == "HIGH")
    map ((m) -> {
        emailId: m.id,
        subject: m.subject,
        sender: m.senderEmail,
        localDate: m.localDate,
        priority: m.priority,
        reasons: m.importanceReasons
    })

var pendingActions = analyzed
    filter ((m) -> not isEmpty(m.pendingKinds))
    map ((m) -> {
        emailId: m.id,
        subject: m.subject,
        sender: m.senderEmail,
        localDate: m.localDate,
        category: m.category,
        kinds: m.pendingKinds
    })

var categoryCounts = {
    COBRANCA: sizeOf(analyzed filter ((m) -> m.category == "COBRANCA")),
    VAGA: sizeOf(analyzed filter ((m) -> m.category == "VAGA")),
    NORMAL: sizeOf(analyzed filter ((m) -> m.category == "NORMAL"))
}

var unreadCount = sizeOf(analyzed filter ((m) -> m.unread))
var readCount = sizeOf(analyzed) - unreadCount

var executiveSummary =
    "Foram analisados " ++ (sizeOf(analyzed) as String)
    ++ " e-mails de " ++ startDate ++ " a " ++ endDate ++ ". "
    ++ (unreadCount as String) ++ " não lidos. "
    ++ "Categorias sugeridas: " ++ (categoryCounts.COBRANCA as String) ++ " de cobrança, "
    ++ (categoryCounts.VAGA as String) ++ " de vagas e "
    ++ (categoryCounts.NORMAL as String) ++ " gerais. "
    ++ (sizeOf(importantEmails) as String) ++ " mensagens potencialmente importantes e "
    ++ (sizeOf(pendingActions) as String) ++ " com possíveis ações pendentes (heurística, a confirmar)."

---
{
    reportId: uuid(),
    generatedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX", timezone: tz},
    timezone: tz,
    period: {
        startDate: startDate,
        endDate: endDate
    },
    filters: {
        includeRead: includeRead,
        includeUnread: includeUnread,
        groupBy: grouping,
        query: req.query default ""
    },
    collection: {
        requestedMax: req.maxEmails,
        fetched: sizeOf(allMessages),
        truncated: payload.collection.truncated default false
    },
    statistics: {
        totalEmails: sizeOf(analyzed),
        readEmails: readCount,
        unreadEmails: unreadCount,
        uniqueSenders: sizeOf(senderStats),
        pendingActions: sizeOf(pendingActions),
        importantEmails: sizeOf(importantEmails),
        skippedInvalidDates: skippedInvalidDates,
        categories: categoryCounts
    },
    frequentSenders: frequentSenders,
    volume: volume,
    importantEmails: importantEmails,
    pendingActions: pendingActions,
    executiveSummary: executiveSummary
}

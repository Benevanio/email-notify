%dw 2.0
output application/json

/**
 * Valida o corpo de POST /reports/emails.
 * Saída: { valid, errors[], request{} } com valores padrão aplicados.
 */

var body = payload default {}
var maxAllowedEmails = p('gmail.maxAllowedMessagesPerReport') as Number
var maxRangeDays = p('report.maxRangeDays') as Number

fun parseDate(value: String) =
    try(() -> (value as Date {format: "yyyy-MM-dd"}))

fun rangeInSeconds(start: Date, end: Date): Number =
    ((end as DateTime) as Number {unit: "seconds"}) - ((start as DateTime) as Number {unit: "seconds"})

var startTry = parseDate(body.startDate default "")
var endTry = parseDate(body.endDate default "")
var groupingMode = body.groupBy default "day"
var includeRead = body.includeRead default true
var includeUnread = body.includeUnread default true
var maxEmails = body.maxEmails default (p('gmail.maxMessagesPerReport') as Number)
var query = body.query default ""
var datesParsed = startTry.success and endTry.success

var dateErrors =
    (if (not startTry.success) ["startDate deve ser uma data válida no formato yyyy-MM-dd."] else [])
    ++ (if (not endTry.success) ["endDate deve ser uma data válida no formato yyyy-MM-dd."] else [])
    ++ (if (datesParsed and startTry.result > endTry.result)
            ["startDate não pode ser posterior a endDate."]
        else [])
    ++ (if (datesParsed and rangeInSeconds(startTry.result, endTry.result) > (maxRangeDays * 86400))
            ["O intervalo entre startDate e endDate excede " ++ (maxRangeDays as String) ++ " dias."]
        else [])

var otherErrors =
    (if (not (["day", "week", "month"] contains groupingMode))
        ["groupBy deve ser day, week ou month."] else [])
    ++ (if ((not includeRead) and (not includeUnread))
        ["Pelo menos um entre includeRead e includeUnread deve ser true."] else [])
    ++ (if (maxEmails < 1 or maxEmails > maxAllowedEmails)
        ["maxEmails deve estar entre 1 e " ++ (maxAllowedEmails as String) ++ "."] else [])

var errors = dateErrors ++ otherErrors

---
{
    valid: isEmpty(errors),
    errors: errors,
    request: {
        startDate: if (startTry.success) (startTry.result as String {format: "yyyy-MM-dd"}) else null,
        endDate: if (endTry.success) (endTry.result as String {format: "yyyy-MM-dd"}) else null,
        groupBy: groupingMode,
        includeRead: includeRead,
        includeUnread: includeUnread,
        maxEmails: maxEmails,
        query: query
    }
}

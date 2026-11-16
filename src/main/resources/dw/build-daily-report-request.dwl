%dw 2.0
output application/json

/**
 * Pedido do relatório diário: últimas 24 h, em datas do fuso report.timezone (ontem até hoje, inclusive).
 */
var tz = p('report.timezone')
var today = now() as String {format: "yyyy-MM-dd", timezone: tz}
var yesterday = ((now() - |P1D|) as String {format: "yyyy-MM-dd", timezone: tz})
---
{
    startDate: yesterday,
    endDate: today,
    groupBy: "day",
    includeRead: true,
    includeUnread: true,
    maxEmails: p('gmail.maxMessagesPerReport') as Number
}

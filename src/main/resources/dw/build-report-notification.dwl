%dw 2.0
output text/plain

/**
 * Texto da notificação no celular após o relatório ser gerado. Não inclui conteúdo de e-mails.
 */
var stats = payload.statistics
---
"Relatório de " ++ payload.period.startDate ++ " a " ++ payload.period.endDate ++ " gerado. "
++ (stats.totalEmails as String) ++ " e-mails analisados: "
++ (stats.categories.COBRANCA as String) ++ " cobranças, "
++ (stats.categories.VAGA as String) ++ " vagas, "
++ (stats.categories.NORMAL as String) ++ " gerais. "
++ (stats.unreadEmails as String) ++ " não lidos, "
++ (stats.pendingActions as String) ++ " com possíveis ações pendentes."

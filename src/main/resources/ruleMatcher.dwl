%dw 2.0

fun ruleMatches(m, rule): Boolean =
    do {
        var value = lower(trim(rule.matchValue default ""))
        var text = lower((m.subject default "") ++ " " ++ (m.snippet default "") ++ " " ++ (m.from default ""))
        ---
        if (rule.ruleType == "PRIORITY_SENDER" or rule.ruleType == "IGNORED_SENDER") m.senderEmail == value
        else if (rule.ruleType == "PRIORITY_DOMAIN") m.senderDomain == value
        else if (rule.ruleType == "SUBJECT") lower(m.subject default "") contains value
        else if (rule.ruleType == "KEYWORD" or rule.ruleType == "IGNORED_KEYWORD") text contains value
        else false
    }

fun urgencyRank(level: String | Null): Number =
    if (level == "CRITICAL") 4
    else if (level == "HIGH") 3
    else if (level == "MEDIUM") 2
    else 1

fun evaluateNotification(m, rules: Array): Object =
    do {
        var active = rules filter ((rule) -> (rule.enabled default true))
        var ignoring = active filter ((rule) ->
            (rule.ruleType == "IGNORED_SENDER" or rule.ruleType == "IGNORED_KEYWORD") and ruleMatches(m, rule))
        var priority = active filter ((rule) ->
            (rule.ruleType == "PRIORITY_SENDER" or rule.ruleType == "PRIORITY_DOMAIN" or rule.ruleType == "KEYWORD" or rule.ruleType == "SUBJECT")
            and ruleMatches(m, rule)
            and urgencyRank(m.classification.urgencyLevel) >= urgencyRank(rule.minUrgency))
        ---
        if (not isEmpty(ignoring)) {notify: false, reason: "Ignorado pela regra: " ++ (ignoring[0].name default "")}
        else if (not isEmpty(priority)) {notify: true, reason: "Regra prioritária: " ++ (priority[0].name default "")}
        else if (m.classification.urgencyLevel == "HIGH" or m.classification.urgencyLevel == "CRITICAL")
            {notify: true, reason: "Urgência " ++ m.classification.urgencyLevel}
        else {notify: false, reason: "Sem regra de notificação aplicável."}
    }

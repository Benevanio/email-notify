%dw 2.0
/**
 * Classificação heurística por palavras-chave.
 * As funções SUGEREM categorias, prioridades e possíveis ações pendentes.
 * Nada aqui confirma uma cobrança, uma vaga ou uma tarefa.
 */

var billingPattern = /(?is).*(cobran[çc]a|fatura|boleto|vencimento|vence em|pagamento|pagar|invoice|payment due|overdue|em atraso|nota fiscal|d[ée]bito|\bpix\b).*/
var jobPattern = /(?is).*(vaga|processo seletivo|recrutad|recruiter|candidatura|candidato|entrevista|hiring|job alert|job opening|oportunidade de (emprego|trabalho)|carreira|career|gupy|linkedin|indeed|catho|infojobs).*/
var urgencyPattern = /(?is).*(urgente|urgent|imediat|immediate|critical|cr[ií]tico).*/
var deadlinePattern = /(?is).*(prazo|deadline|at[ée] (o |a )?(dia|hoje|amanh[ãa])|vence hoje|vence amanh[ãa]|expira|due date|vencimento).*/
var importantPattern = /(?is).*(importante|important|aprova[çc][ãa]o|approval).*/

var pendingKindPatterns = [
    {kind: "CONFIRMATION", pattern: /(?is).*(confirm|confirma[çc]).*/},
    {kind: "RESPONSE_REQUEST", pattern: /(?is).*(responder|resposta|retorno|retornar|reply|respond|aguardo|aguardando|poderia|pode me|could you|can you).*/},
    {kind: "DEADLINE", pattern: deadlinePattern},
    {kind: "REQUEST", pattern: /(?is).*(preciso|solicit|favor|please|precisamos|requisi).*/}
]

fun searchableText(message): String =
    (message.subject default "") ++ " " ++ (message.snippet default "") ++ " " ++ (message.from default "")

fun classifyCategory(message): String =
    do {
        var text = searchableText(message)
        ---
        if (text matches billingPattern) "COBRANCA"
        else if (text matches jobPattern) "VAGA"
        else "NORMAL"
    }

fun pendingKinds(message): Array<String> =
    do {
        var text = searchableText(message)
        ---
        (pendingKindPatterns filter ((item) -> text matches item.pattern)) map ((item) -> item.kind)
    }

fun priorityOf(message, kinds: Array<String>): String =
    do {
        var text = searchableText(message)
        ---
        if (text matches urgencyPattern) "CRITICAL"
        else if ((text matches deadlinePattern) or (text matches importantPattern)) "HIGH"
        else if ((message.unread default false) or (not isEmpty(kinds))) "MEDIUM"
        else "LOW"
    }

fun importanceReasons(message): Array<String> =
    do {
        var text = searchableText(message)
        ---
        (if (message.unread default false) ["Mensagem ainda não lida."] else [])
        ++ (if (text matches urgencyPattern) ["Contém termos de urgência."] else [])
        ++ (if (text matches deadlinePattern) ["Menciona prazo ou vencimento."] else [])
        ++ (if (text matches importantPattern) ["Contém termos de importância ou aprovação."] else [])
    }

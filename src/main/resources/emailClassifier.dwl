%dw 2.0
var billingPattern = /(?is).*(cobran[çc]a|fatura|boleto|vencimento|vence em|pagamento|pagar|invoice|payment due|overdue|em atraso|nota fiscal|d[ée]bito|\bpix\b).*/
var jobPattern = /(?is).*(vaga|processo seletivo|recrutad|recruiter|candidatura|candidato|entrevista|hiring|job alert|job opening|oportunidade de (emprego|trabalho)|carreira|career|gupy|linkedin|indeed|catho|infojobs).*/
var urgencyPattern = /(?is).*(urgente|urgent|imediat|immediate|critical|cr[ií]tico).*/
var deadlinePattern = /(?is).*(prazo|deadline|at[ée] (o |a )?(dia|hoje|amanh[ãa])|vence hoje|vence amanh[ãa]|expira|due date).*/
var actionPattern = /(?is).*(preciso|solicit|favor|please|confirme|confirmar|confirm|responder|resposta|retorno|retornar|reply|respond|aguardo|aguardando|aprovar|aprova[çc][ãa]o|approve|poderia|pode me|could you|can you).*/
var newsletterPattern = /(?is).*(newsletter|unsubscribe|descadastr|promo[çc][ãa]o|promo|oferta|desconto|no-?reply|noreply|cupom).*/
var importantPattern = /(?is).*(importante|important).*/

fun triage(m): Object =
    do {
        var text = (m.subject default "") ++ " " ++ (m.snippet default "") ++ " " ++ (m.from default "")
        var urgent = text matches urgencyPattern
        var deadline = text matches deadlinePattern
        var billing = text matches billingPattern
        var action = text matches actionPattern
        var important = text matches importantPattern
        var job = text matches jobPattern
        var newsletter = text matches newsletterPattern
        var category =
            if (urgent or (deadline and (action or billing))) "URGENTE"
            else if (billing or deadline or important) "IMPORTANTE"
            else if (action) "ACAO_NECESSARIA"
            else if (newsletter) "BAIXA_PRIORIDADE"
            else "INFORMATIVO"
        var urgencyLevel =
            if (urgent) "CRITICAL"
            else if (deadline) "HIGH"
            else if (category == "IMPORTANTE" or category == "ACAO_NECESSARIA") "MEDIUM"
            else "LOW"
        var reasons =
            (if (urgent) ["Contém termo de urgência."] else [])
            ++ (if (deadline) ["Menciona prazo ou vencimento."] else [])
            ++ (if (billing) ["Parece cobrança, fatura ou boleto."] else [])
            ++ (if (important) ["Contém termo de importância."] else [])
            ++ (if (action) ["Pode exigir resposta ou confirmação."] else [])
            ++ (if (job) ["Parece oportunidade de vaga."] else [])
            ++ (if (newsletter) ["Parece promoção, newsletter ou aviso automático."] else [])
        ---
        {
            category: category,
            urgencyLevel: urgencyLevel,
            requiresAction: action or deadline,
            possibleAction: if (action or deadline) "Avaliar se há resposta, confirmação ou prazo." else null,
            classificationReason: if (isEmpty(reasons)) "Nenhum indicador encontrado." else (reasons joinBy " "),
            classifierVersion: "heuristic-v1"
        }
    }

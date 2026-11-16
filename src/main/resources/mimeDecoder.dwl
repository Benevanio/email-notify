%dw 2.0
/**
 * Funções para extrair cabeçalhos e texto plano de mensagens MIME do Gmail.
 * O Gmail devolve o corpo em Base64URL (alfabeto com '-' e '_', sem padding obrigatório).
 */
import * from dw::core::Arrays

fun headerValue(message, headerName: String): String | Null =
    do {
        var headers = (message.payload.headers default []) as Array
        var found = firstWith(headers, (header) ->
            lower(header.name default "") == lower(headerName))
        ---
        (found default {}).value default null
    }

fun decodeBase64Url(data: String): String =
    (((data replace "-" with "+") replace "_" with "/") as Binary {encoding: "base64"}) as String {encoding: "UTF-8"}

fun textPartsOf(part): Array =
    if (((part.mimeType default "") == "text/plain") and ((part.body.data default null) != null))
        [part]
    else (part.parts default []) flatMap ((child) -> textPartsOf(child))

fun plainTextBody(payload): String =
    do {
        var parts = textPartsOf(payload)
        var decoded = parts map ((part) ->
            (try(() -> decodeBase64Url(part.body.data)).result) default "")
        ---
        decoded joinBy "\n"
    }

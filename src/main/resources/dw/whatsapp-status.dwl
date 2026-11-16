%dw 2.0
output application/json

fun mapStatus(value: String): String | Null =
    if (value == "sent") "SENT"
    else if (value == "delivered") "DELIVERED"
    else if (value == "read") "READ"
    else if (value == "failed") "FAILED"
    else null

var statuses = (payload.entry default []) flatMap ((entry) ->
    (entry.changes default []) flatMap ((change) -> change.value.statuses default []))
---
statuses map ((status) -> {
    providerMessageId: status.id,
    status: mapStatus(status.status default ""),
    errorCode: if (isEmpty(status.errors default [])) null else (status.errors[0].code as String)
}) filter ((item) -> item.status != null)

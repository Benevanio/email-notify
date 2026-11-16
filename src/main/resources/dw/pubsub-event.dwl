%dw 2.0
output application/json

var raw = ((payload.message.data default "") as Binary {encoding: "base64"}) as String {encoding: "UTF-8"}
var data = read(raw, "application/json")
---
{
    emailAddress: lower(data.emailAddress default ""),
    historyId: (data.historyId default "") as String,
    messageId: payload.message.messageId default ""
}

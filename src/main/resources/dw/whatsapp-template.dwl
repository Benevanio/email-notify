%dw 2.0
output application/json

---
{
    messaging_product: "whatsapp",
    recipient_type: "individual",
    to: payload.to,
    type: "template",
    template: {
        name: payload.templateName,
        language: {code: payload.language},
        components: [
            {
                "type": "body",
                parameters: (payload.parameters default []) map ((value) -> {"type": "text", text: value as String})
            }
        ]
    }
}

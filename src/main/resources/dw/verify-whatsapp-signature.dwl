%dw 2.0
output application/json
import * from dw::Crypto
import * from dw::core::Binaries

var body = write(vars.webhookBody, "application/json") as Binary {encoding: "UTF-8"}
var expected = "sha256=" ++ toHex(HMACBinary(body, p('whatsapp.appSecret'), "HmacSHA256"))
---
expected == ((vars.signatureHeader default "") as String)

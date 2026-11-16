%dw 2.0
output application/java
import java!com::benenotify::security::TokenCipher

var row = payload[0]
var key = p('security.tokenEncryptionKey')
---
{
    accountId: row.account_id,
    refreshToken: TokenCipher::decrypt(row.refresh_token_encrypted, key),
    accessToken: if (row.access_token_encrypted == null) null else TokenCipher::decrypt(row.access_token_encrypted, key),
    accessValid: row.access_valid
}

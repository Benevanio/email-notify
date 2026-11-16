%dw 2.0
output application/java
import java!com::benenotify::security::TokenCipher
---
TokenCipher::encrypt(vars.plainAccessToken, p('security.tokenEncryptionKey'))

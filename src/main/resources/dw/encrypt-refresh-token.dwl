%dw 2.0
output application/java
import java!com::benenotify::security::TokenCipher
---
TokenCipher::encrypt(vars.plainRefreshToken, p('security.tokenEncryptionKey'))

%dw 2.0
output application/json
import * from ruleMatcher

---
evaluateNotification(vars.normalizedMessage, vars.rules default [])

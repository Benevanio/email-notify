%dw 2.0
output application/json
import dw::core::URL

/**
 * URL de autorização OAuth 2.0 do Google. Escopo somente leitura.
 * vars.oauthState: valor aleatório salvo no OAuth_State_Store para validação do callback.
 */
var params = {
    client_id: p('google.clientId'),
    redirect_uri: p('google.redirectUri'),
    response_type: "code",
    scope: p('google.scope'),
    access_type: "offline",
    prompt: "consent",
    include_granted_scopes: "false",
    state: vars.oauthState
}
var query = (params pluck ((value, key) ->
    URL::encodeURIComponent(key as String) ++ "=" ++ URL::encodeURIComponent(value as String))) joinBy "&"
---
{
    authorizationUrl: p('google.authorizationUrl') ++ "?" ++ query,
    state: vars.oauthState,
    scope: p('google.scope')
}

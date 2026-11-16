# Bene Notify

Sistema pessoal de monitoramento de e-mails do Gmail. Lê a caixa de entrada, classifica cada mensagem com regras heurísticas, aplica regras de notificação e envia avisos pelo WhatsApp Business Cloud API (API oficial da Meta). Também gera um relatório diário e o envia pelo WhatsApp.

> **Status:** implementação em andamento. O código foi escrito, mas **nada foi compilado nem executado** ainda. Veja [Estado atual e pendências](#estado-atual-e-pendências) antes de usar.

## Sumário

- [Arquitetura](#arquitetura)
- [Stack](#stack)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Funcionalidades](#funcionalidades)
- [Classificação e regras](#classificação-e-regras)
- [API](#api)
- [Configuração](#configuração)
- [Banco de dados](#banco-de-dados)
- [Configuração no Google Cloud](#configuração-no-google-cloud)
- [Configuração na Meta (WhatsApp)](#configuração-na-meta-whatsapp)
- [Build e execução](#build-e-execução)
- [Segurança](#segurança)
- [Operação](#operação)
- [Estado atual e pendências](#estado-atual-e-pendências)

## Arquitetura

```text
Site (Vercel) ──HTTPS──► API MuleSoft (VPS Linux)
                              │
          ┌───────────────────┼────────────────────┐
          │                   │                    │
     Gmail API          WhatsApp Cloud API     PostgreSQL
  (somente leitura)     (templates aprovados)
          ▲
          │ Pub/Sub push (OIDC) → /webhooks/google-pubsub
```

Fluxo de uma notificação:

1. O Gmail publica um evento no tópico Pub/Sub quando chega uma mensagem na caixa de entrada.
2. A API valida o token OIDC do Google e grava o evento. Não processa o e-mail no webhook.
3. Um job `PROCESS_GMAIL_HISTORY` lê `users.history.list` a partir do último `historyId` salvo.
4. Cada mensagem nova é buscada em metadados, normalizada e classificada.
5. A classificação e a mensagem são gravadas no banco. Se houver regra de notificação, cria-se uma notificação e um job `SEND_NOTIFICATION`.
6. O worker envia o template pelo WhatsApp e registra a tentativa. Falhas geram retry com backoff.
7. Os status de entrega (`sent`, `delivered`, `read`, `failed`) chegam pelo webhook do WhatsApp e atualizam a notificação.

Não há corpo de e-mail armazenado. O banco guarda remetente, assunto, trecho curto (snippet), datas, labels e a classificação.

## Stack

| Camada | Tecnologia |
|---|---|
| Backend | MuleSoft Runtime 4.11 (Community) |
| Contrato da API | RAML 1.0 + APIkit 1.13.5 |
| Transformações | DataWeave 2 |
| Banco | PostgreSQL (driver 42.7.4, conector `mule-db-connector` 1.16.3) |
| HTTP | `mule-http-connector` 1.11.1 |
| Fila e cache | Object Store (estado OAuth em memória) |
| Arquivos | `mule-file-connector` 1.5.6 (relatórios diários em disco) |
| Cifragem de tokens | AES-256-GCM via classe Java (`javax.crypto`) |
| Build | Maven, `mule-maven-plugin` 4.7.0, Java 17 |
| Testes | MUnit 3.7.6 (ainda não implementados) |

## Estrutura do projeto

```text
.
├── pom.xml                          Dependências e plugins Maven
├── mule-artifact.json               minMuleVersion 4.11.0, Java 17
├── .env.example                     Variáveis de ambiente (não é carregado automaticamente)
├── db/migrations/V1__init.sql       Schema PostgreSQL
├── src/main/java/com/benenotify/security/TokenCipher.java
│                                    Cifragem AES-256-GCM dos tokens OAuth
├── src/main/mule/
│   ├── global-config.xml            Listener, APIkit, banco, clientes HTTP, Object Store
│   ├── gmail-api.xml                Entrada única e roteamento APIkit
│   ├── gmail-oauth-flows.xml        Autorização, callback, renovação de token, watch
│   ├── gmail-connector.xml          Chamada genérica à Gmail API (retry, 401→refresh, erros)
│   ├── gmail-email-flows.xml        Consulta de e-mails monitorados e labels
│   ├── gmail-report-flows.xml       Relatório sob demanda e job diário
│   ├── gmail-error-handler.xml      Mapeamento global de erros → HTTP + código estável
│   ├── notification-flows.xml       Envio WhatsApp, listagem, detalhe e reenvio
│   ├── rules-flows.xml              CRUD de regras de notificação
│   ├── webhook-flows.xml            Pub/Sub (OIDC) e WhatsApp (verificação e status)
│   ├── worker-flows.xml             Fila de jobs, histórico do Gmail, classificação
│   └── status-flows.xml             Status do sistema, Gmail e painel
└── src/main/resources/
    ├── api/gmail-intelligence-api.raml   Contrato da API (fonte do APIkit)
    ├── env-dev.yaml                      Propriedades (segredos via ${VAR})
    ├── emailClassifier.dwl               Classificação heurística
    ├── messageNormalizer.dwl             Normalização de mensagens do Gmail
    ├── mimeDecoder.dwl                   Cabeçalhos e Base64URL
    ├── ruleMatcher.dwl                   Avaliação das regras de notificação
    └── dw/                               Scripts de transformação de cada flow
```

## Funcionalidades

- **Autorização Google (OAuth 2.0, escopo `gmail.readonly`):** URL com `state` aleatório (validado no callback, expira em 10 minutos), troca do código, `access_type=offline` e `prompt=consent`.
- **Armazenamento de tokens:** refresh e access tokens são cifrados com AES-256-GCM antes de entrar em `oauth_tokens`. A chave vem de `TOKEN_ENCRYPTION_KEY`.
- **Renovação automática:** o access token é renovado quando falta menos de `google.refreshMarginMs`. Refresh token revogado marca a conta como `ERROR` e exige nova autorização.
- **Monitoramento:** Gmail `users.watch` com Pub/Sub, renovado por job horário quando faltar menos de 1 dia. A sincronização usa `users.history.list` com cursor salvo. Se o histórico expirar, roda um fallback nas últimas mensagens.
- **Deduplicação:** índices únicos em `(conta, gmail_message_id)`, `(email, versão de classificação)`, `(email, canal)` e `(tipo, dedupe_key)` dos jobs.
- **Relatórios:** `POST /reports/emails` consulta o Gmail no intervalo pedido, aplica os filtros de data e leitura e agrega por remetente, período (dia/semana/mês), categoria e urgência. Não inclui corpos de e-mail.
- **Relatório diário:** às 08:00 (fuso `America/Fortaleza`, configurável) gera o relatório das últimas 24 h, salva em `reports/` e envia um resumo pelo WhatsApp com template aprovado.
- **Notificações:** regras de prioridade e ignorados, mais urgência HIGH/CRITICAL. Reenvio manual apenas para notificações em `FAILED`.

## Classificação e regras

A classificação é **heurística por palavras-chave**. Ela sugere; não confirma cobrança, vaga ou tarefa. Cada resultado traz `classificationReason` com os motivos. Versão atual: `heuristic-v1`.

| Categoria | Quando |
|---|---|
| `URGENTE` | Termo de urgência, ou prazo combinado com pedido de ação ou cobrança |
| `IMPORTANTE` | Cobrança, fatura, boleto, prazo ou termo de importância |
| `ACAO_NECESSARIA` | Pedido de resposta, confirmação ou aprovação |
| `BAIXA_PRIORIDADE` | Promoção, newsletter ou aviso automático |
| `INFORMATIVO` | Demais casos (inclui oportunidades de vaga, marcadas no motivo) |

Urgência: `CRITICAL` (termo de urgência), `HIGH` (prazo), `MEDIUM` (importante ou ação), `LOW` (demais).

Regras de notificação (tabela `notification_rules`, tipos `PRIORITY_SENDER`, `PRIORITY_DOMAIN`, `KEYWORD`, `SUBJECT`, `IGNORED_SENDER`, `IGNORED_KEYWORD`). A ordem é:

1. Regra de ignorar que casa → não notifica.
2. Regra de prioridade que casa e atinge `minUrgency` → notifica.
3. Urgência `HIGH` ou `CRITICAL` → notifica.
4. Caso contrário, não notifica.

## API

Base: `{baseUri}/api/v1`. Um contrato completo está em `src/main/resources/api/gmail-intelligence-api.raml`.

Endpoints públicos (sem Bearer): `GET /health`, `GET /gmail/callback`, `POST /webhooks/google-pubsub`, `GET|POST /webhooks/whatsapp`. As rotas de administração exigem `Authorization: Bearer <token>` no header. **A validação desse token ainda não está implementada no fluxo.** Veja pendências.

| Método | Caminho | Descrição |
|---|---|---|
| GET | `/health` | Disponibilidade |
| GET | `/status` | Banco, Gmail e WhatsApp |
| GET | `/gmail/status` | Estado da conexão e do monitoramento |
| GET | `/gmail/authorize` | URL de autorização OAuth |
| GET | `/gmail/callback` | Callback OAuth (state validado, tokens cifrados) |
| POST | `/gmail/disconnect` | Para o watch e revoga os tokens |
| POST | `/gmail/sync` | Enfileira sincronização (202) |
| GET | `/gmail/emails` | Lista e-mails monitorados (filtros: category, urgencyLevel, sender, from, to; paginação por cursor) |
| GET | `/gmail/emails/unread` | E-mails não lidos |
| GET | `/gmail/emails/{id}` | Detalhe (sem corpo) |
| GET | `/gmail/labels` | Labels com contadores (somente leitura) |
| POST | `/reports/emails` | Relatório do período |
| GET | `/reports/summary` | Indicadores do painel |
| GET | `/notifications` | Histórico de notificações |
| GET | `/notifications/{id}` | Detalhe |
| POST | `/notifications/{id}/retry` | Reenvia notificação em `FAILED` (202) |
| GET, POST | `/rules` | Lista e cria regras |
| GET, PUT, DELETE | `/rules/{id}` | Consulta, altera e remove regra |
| POST | `/webhooks/google-pubsub` | Notificação do Gmail (204) |
| GET | `/webhooks/whatsapp` | Verificação do webhook pela Meta |
| POST | `/webhooks/whatsapp` | Status de entrega (assinatura `X-Hub-Signature-256`) |

Erros seguem `{ code, message, correlationId, details }`. `details` aparece só em erros de validação. Respostas nunca trazem tokens, headers de autorização, corpos de e-mail ou stack trace.

## Configuração

Os segredos **não são lidos de `.env`**. O Mule não carrega esse arquivo. O `env-dev.yaml` usa `${VAR}`, resolvido a partir de variáveis de ambiente do processo (ou propriedades de sistema `-M-D...`). O `.env.example` lista todas as variáveis. Não versione o arquivo com valores reais.

Principais variáveis:

| Variável | Uso |
|---|---|
| `APP_ENVIRONMENT`, `HTTP_HOST`, `HTTP_PORT` | Ambiente e listener |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | PostgreSQL |
| `TOKEN_ENCRYPTION_KEY` | Chave AES-256 em Base64 (32 bytes). Gere com `openssl rand -base64 32` |
| `ADMIN_DASHBOARD_URL`, `CORS_ORIGIN` | Painel e origem permitida |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI` | OAuth |
| `PUBSUB_TOPIC`, `PUBSUB_AUDIENCE`, `PUBSUB_SERVICE_ACCOUNT` | Pub/Sub e validação OIDC |
| `META_ACCESS_TOKEN`, `META_PHONE_NUMBER_ID`, `META_APP_SECRET`, `META_VERIFY_TOKEN`, `META_GRAPH_API_VERSION` | WhatsApp Cloud API |
| `WHATSAPP_RECIPIENT_NUMBER`, `WHATSAPP_TEMPLATE_NAME`, `WHATSAPP_TEMPLATE_LANGUAGE`, `WHATSAPP_DAILY_TEMPLATE_NAME` | Destinatário e templates |

Valores fixos de exemplo em `env-dev.yaml` (fuso, cron, limites) podem ser ajustados lá.

## Banco de dados

- Schema em `db/migrations/V1__init.sql`, com as tabelas: `integration_accounts`, `oauth_tokens`, `sync_state`, `emails`, `email_classifications`, `notification_rules`, `webhook_events`, `processing_jobs`, `notifications`, `notification_attempts`, `audit_logs`.
- **Não há ferramenta de migração automatizada.** Aplique manualmente, em um banco vazio:

  ```bash
  psql "postgresql://$DB_USER@$DB_HOST:$DB_PORT/$DB_NAME" -f db/migrations/V1__init.sql
  ```

- `pgcrypto` é usado para `gen_random_uuid()`.
- O worker assume **uma única instância** da aplicação.

## Configuração no Google Cloud

1. Crie um projeto e ative a **Gmail API**.
2. Em **Tela de consentimento OAuth**, configure o app. Adicione o escopo `https://www.googleapis.com/auth/gmail.readonly`. Enquanto o app estiver em modo de teste, o refresh token expira em 7 dias.
3. Em **Credenciais**, crie um cliente OAuth "Aplicativo da Web". Em *URIs de redirecionamento autorizados*, adicione `https://SEU_DOMINIO/api/v1/gmail/callback`. Esse valor precisa ser idêntico a `GOOGLE_REDIRECT_URI`.
4. Crie um tópico Pub/Sub (`PUBSUB_TOPIC`).
5. Conceda à conta de serviço do Gmail (`gmail-api-push@system.gserviceaccount.com`) a permissão **Pub/Sub Publisher** no tópico. Sem isso, `users.watch` falha.
6. Crie uma assinatura **push** para o tópico, apontando para `https://SEU_DOMINIO/api/v1/webhooks/google-pubsub`. Ative a autenticação OIDC, com:
   - conta de serviço = `PUBSUB_SERVICE_ACCOUNT`;
   - audiência = `PUBSUB_AUDIENCE` (use a mesma URL do endpoint).
7. Autorize a conta pelo `GET /gmail/authorize` e abra a URL retornada.

## Configuração na Meta (WhatsApp)

1. No Meta for Developers, crie um app do tipo Business e adicione o produto **WhatsApp**.
2. Registre o número, e anote `META_PHONE_NUMBER_ID` e `META_BUSINESS_ACCOUNT_ID`. Gere um token de acesso permanente (system user) para `META_ACCESS_TOKEN`.
3. Em **Configurações do app**, copie o *Segredo do app* para `META_APP_SECRET`.
4. Crie os templates no WhatsApp Manager e aguarde a aprovação. **Os nomes e a quantidade de parâmetros precisam bater com o código.**

   **Template de notificação** (`WHATSAPP_TEMPLATE_NAME`, idioma `WHATSAPP_TEMPLATE_LANGUAGE`), com 6 variáveis no corpo, nesta ordem:
   `{{1}}` remetente · `{{2}}` assunto · `{{3}}` urgência (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`) · `{{4}}` data (dd/MM/yyyy HH:mm) · `{{5}}` motivo da classificação · `{{6}}` link do painel.

   **Template diário** (`WHATSAPP_DAILY_TEMPLATE_NAME`), com 6 variáveis, nesta ordem:
   `{{1}}` período · `{{2}}` total de e-mails · `{{3}}` urgentes · `{{4}}` importantes · `{{5}}` não lidos · `{{6}}` possíveis ações pendentes.

   Exemplo de corpo do template diário: `Relatório de {{1}} gerado: {{2}} e-mails, {{3}} urgentes, {{4}} importantes, {{5}} não lidos, {{6}} com possível ação.`

5. Em **Webhooks**, configure a URL `https://SEU_DOMINIO/api/v1/webhooks/whatsapp`, com o *Verify token* igual a `META_VERIFY_TOKEN`. Assine o campo `messages`.

Mensagens iniciadas pela empresa fora da janela de 24 horas só podem ser enviadas por template aprovado. O código envia apenas templates.

## Build e execução

Pré-requisitos: JDK 17, Maven 3.9+, PostgreSQL 14+, acesso aos repositórios MuleSoft (já configurados no `pom.xml`).

```bash
# Banco
psql ... -f db/migrations/V1__init.sql

# Variáveis (exemplo em bash)
set -a; source ./meu.env; set +a   # arquivo local fora do versionamento

# Build
mvn -B clean package

# Execução: aplicação empacotada no Mule Runtime 4.11 standalone (ver pendência de licença)
```

Os testes ainda não existem. `mvn test` executará o MUnit quando as suítes forem criadas.

## Segurança

- Tokens OAuth cifrados (AES-256-GCM) no banco. Chave fora do repositório.
- `state` OAuth anti-CSRF, validado e consumido uma vez.
- Webhook do Pub/Sub validado no servidor do Google (`tokeninfo`): emissor, audiência, e-mail da conta de serviço e e-mail verificado.
- Webhook do WhatsApp com verificação HMAC-SHA256 (`X-Hub-Signature-256`).
- Escopo somente leitura no Gmail. Nenhuma operação de escrita é chamada.
- Logs registram tipo de erro, código e `correlationId`. Não registram tokens, headers nem conteúdo de e-mail.
- `.gitignore` cobre `.env`, `reports/` e `.mule/`, que guarda o estado local.

## Operação

- **Relatórios:** arquivos em `reports/daily-report-AAAA-MM-DD.json`.
- **Fila:** jobs em `processing_jobs`. Jobs que falham voltam a `PENDING` com backoff (30 s × 2^tentativas), até `max_attempts`, quando viram `DEAD`.
- **Watch:** renovado pelo job `RENEW_WATCH`, agendado de hora em hora.
- **Health:** `GET /health` (sem auth) e `GET /status` (com auth, quando implementada).

## Estado atual e pendências

**Implementado no código (não validado por build ou execução):**
- Contrato RAML e roteamento APIkit de todos os endpoints listados.
- OAuth com cifragem de tokens, renovação, desconexão e watch.
- Sincronização por histórico, classificação, regras, notificações e fila de jobs.
- Relatórios e job diário via WhatsApp.
- Schema PostgreSQL V1.

**Não verificado:**
- Nenhum build Maven foi executado.
- Pontos com risco de API: `import java!` do DataWeave, `toHex` e `HMACBinary`, binding de `byte[]` no conector de banco, `make_interval`, slicing de strings e `ee:variables` com `resource`.
- A assinatura do WhatsApp é calculada sobre o JSON re-serializado, não sobre o corpo bruto. Isso pode rejeitar eventos válidos. Precisa de um listener que entregue o corpo cru.
- Não sei se o APIkit resolve `/api/v1/...` com o listener em `/api/*`.

**Pendências de implementação:**
- Validação do Bearer nas rotas administrativas. Hoje, `/gmail/*`, `/reports/*`, `/notifications*` e `/rules*` **não exigem autenticação**. Isso precisa ser corrigido antes de expor a API.
- Frontend administrativo no site da Vercel (dashboard, histórico, integrações e regras).
- Testes MUnit (nenhum escrito).
- Runner de migrations.
- Documentação de deploy na VPS (systemd, reverse proxy, HTTPS, backup).

**Pendências externas:**
- Domínio público da API. O `baseUri` do RAML ainda é `https://api.example.com/api/v1`.
- Licença do Mule Community para produção. O kernel está sob CPAL 1.0, mas não há confirmação oficial sobre uso em produção, nem sobre os conectores.
- Credenciais Google (cliente OAuth, tópico Pub/Sub, assinatura push).
- Credenciais Meta (app, número, token, templates aprovados).
- Chave `TOKEN_ENCRYPTION_KEY` e senha do PostgreSQL.

## Licença

Pendente de definição.

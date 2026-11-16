CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE integration_accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    provider varchar(20) NOT NULL CHECK (provider IN ('GMAIL', 'WHATSAPP')),
    external_account varchar(320) NOT NULL,
    status varchar(20) NOT NULL CHECK (status IN ('PENDING', 'CONNECTED', 'ERROR', 'DISCONNECTED')),
    granted_scope text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_integration_accounts_provider_account UNIQUE (provider, external_account)
);

CREATE TABLE oauth_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    integration_account_id uuid NOT NULL REFERENCES integration_accounts (id) ON DELETE CASCADE,
    refresh_token_encrypted bytea NOT NULL,
    access_token_encrypted bytea,
    access_token_expires_at timestamptz,
    encryption_key_version smallint NOT NULL DEFAULT 1,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_oauth_tokens_account UNIQUE (integration_account_id)
);

CREATE TABLE sync_state (
    integration_account_id uuid PRIMARY KEY REFERENCES integration_accounts (id) ON DELETE CASCADE,
    history_id varchar(64),
    watch_expiration timestamptz,
    last_sync_at timestamptz,
    last_sync_status varchar(20) CHECK (last_sync_status IN ('SUCCEEDED', 'FAILED')),
    last_error_code varchar(60),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE emails (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    integration_account_id uuid NOT NULL REFERENCES integration_accounts (id) ON DELETE CASCADE,
    gmail_message_id varchar(64) NOT NULL,
    gmail_thread_id varchar(64) NOT NULL,
    sender_email varchar(320) NOT NULL,
    sender_domain varchar(255) NOT NULL,
    sender_name varchar(255),
    subject varchar(998),
    snippet varchar(500),
    received_at timestamptz NOT NULL,
    is_unread boolean NOT NULL DEFAULT false,
    label_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_emails_account_message UNIQUE (integration_account_id, gmail_message_id)
);

CREATE INDEX ix_emails_received_at ON emails (received_at DESC);
CREATE INDEX ix_emails_sender_email ON emails (sender_email);
CREATE INDEX ix_emails_thread ON emails (gmail_thread_id);
CREATE INDEX ix_emails_unread ON emails (is_unread) WHERE is_unread = true;

CREATE TABLE email_classifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email_id uuid NOT NULL REFERENCES emails (id) ON DELETE CASCADE,
    classifier_version varchar(32) NOT NULL,
    category varchar(30) NOT NULL CHECK (category IN ('URGENTE', 'IMPORTANTE', 'ACAO_NECESSARIA', 'INFORMATIVO', 'BAIXA_PRIORIDADE')),
    urgency_level varchar(10) NOT NULL CHECK (urgency_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    requires_action boolean NOT NULL DEFAULT false,
    possible_action varchar(200),
    classification_reason text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_email_classifications_version UNIQUE (email_id, classifier_version)
);

CREATE INDEX ix_email_classifications_category ON email_classifications (category, urgency_level);

CREATE TABLE notification_rules (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name varchar(120) NOT NULL,
    rule_type varchar(30) NOT NULL CHECK (rule_type IN ('PRIORITY_SENDER', 'PRIORITY_DOMAIN', 'KEYWORD', 'SUBJECT', 'IGNORED_SENDER', 'IGNORED_KEYWORD')),
    match_value varchar(255) NOT NULL,
    min_urgency varchar(10) CHECK (min_urgency IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    enabled boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_notification_rules_match UNIQUE (rule_type, match_value)
);

CREATE TABLE webhook_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source varchar(20) NOT NULL CHECK (source IN ('GOOGLE_PUBSUB', 'WHATSAPP')),
    external_event_id varchar(255) NOT NULL,
    status varchar(20) NOT NULL CHECK (status IN ('RECEIVED', 'PROCESSED', 'IGNORED', 'FAILED')),
    error_code varchar(60),
    received_at timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz,
    CONSTRAINT uq_webhook_events_source_event UNIQUE (source, external_event_id)
);

CREATE TABLE processing_jobs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_type varchar(40) NOT NULL CHECK (job_type IN ('PROCESS_GMAIL_HISTORY', 'CLASSIFY_EMAIL', 'SEND_NOTIFICATION', 'RENEW_WATCH', 'SYNC_FALLBACK')),
    dedupe_key varchar(255) NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    status varchar(20) NOT NULL CHECK (status IN ('PENDING', 'RUNNING', 'SUCCEEDED', 'FAILED', 'DEAD')),
    attempts integer NOT NULL DEFAULT 0,
    max_attempts integer NOT NULL DEFAULT 5,
    run_after timestamptz NOT NULL DEFAULT now(),
    locked_by varchar(100),
    locked_until timestamptz,
    last_error_code varchar(60),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_processing_jobs_dedupe UNIQUE (job_type, dedupe_key)
);

CREATE INDEX ix_processing_jobs_pickup ON processing_jobs (status, run_after);

CREATE TABLE notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email_id uuid NOT NULL REFERENCES emails (id) ON DELETE CASCADE,
    classification_id uuid REFERENCES email_classifications (id) ON DELETE SET NULL,
    channel varchar(20) NOT NULL CHECK (channel IN ('WHATSAPP')),
    recipient_phone varchar(20) NOT NULL,
    template_name varchar(120) NOT NULL,
    template_language varchar(10) NOT NULL,
    status varchar(20) NOT NULL CHECK (status IN ('PENDING', 'SENT', 'DELIVERED', 'READ', 'FAILED', 'SKIPPED')),
    provider_message_id varchar(128),
    last_error_code varchar(60),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    sent_at timestamptz,
    delivered_at timestamptz,
    CONSTRAINT uq_notifications_email_channel UNIQUE (email_id, channel)
);

CREATE UNIQUE INDEX ux_notifications_provider_message ON notifications (provider_message_id) WHERE provider_message_id IS NOT NULL;
CREATE INDEX ix_notifications_status ON notifications (status, created_at DESC);

CREATE TABLE notification_attempts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id uuid NOT NULL REFERENCES notifications (id) ON DELETE CASCADE,
    attempt_number integer NOT NULL CHECK (attempt_number > 0),
    status varchar(20) NOT NULL CHECK (status IN ('SUCCEEDED', 'FAILED')),
    http_status integer,
    error_code varchar(60),
    attempted_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_notification_attempts_number UNIQUE (notification_id, attempt_number)
);

CREATE TABLE audit_logs (
    id bigserial PRIMARY KEY,
    actor varchar(255) NOT NULL,
    action varchar(80) NOT NULL,
    entity_type varchar(60),
    entity_id varchar(64),
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    correlation_id varchar(64),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_audit_logs_created_at ON audit_logs (created_at DESC);

%dw 2.0
output application/json

fun labelsOf(raw): Array =
    if (raw == null) [] else read(raw as String, "application/json")

fun itemOf(row): Object =
    {
        id: row.id as String,
        gmailMessageId: row.gmail_message_id,
        gmailThreadId: row.gmail_thread_id,
        senderEmail: row.sender_email,
        senderDomain: row.sender_domain,
        senderName: row.sender_name,
        subject: row.subject,
        snippet: row.snippet,
        receivedAt: row.received_at,
        unread: row.is_unread,
        labelIds: labelsOf(row.label_ids),
        classification: if (row.category == null) null else {
            category: row.category,
            urgencyLevel: row.urgency_level,
            requiresAction: row.requires_action,
            possibleAction: row.possible_action,
            classificationReason: row.classification_reason,
            classifierVersion: row.classifier_version
        }
    }

---
itemOf(payload[0])

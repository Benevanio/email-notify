%dw 2.0
output application/json
import * from dw::core::Arrays

var entries = payload.history default []
var added = entries flatMap ((entry) -> (entry.messagesAdded default []) map ((item) -> item.message.id))
---
{
    historyId: payload.historyId default null,
    nextPageToken: payload.nextPageToken default null,
    messageIds: added distinctBy ((id) -> id)
}

# NYX Toolkit

Status: **written, statically checked only. Not compiled, tests not run** (no Swift toolchain was available).

- **Event log** (`NYXEventLog`): local, capped at 500 events, text cut at 300 chars, search/severity filter. Currently records what the Toolkit itself does (rules added/deleted, recovery of damaged files). Other features do not write to it yet.
- **Message filter rules** (`NYXMessageFilter`): contains / whole word / validated regex, actions hide / mute / highlight, strongest action wins. Pattern ≤200 chars, ≤100 rules. **Not yet applied to chats**: the screen tests rules on text you type.
- **Streamer masking** (`NYXRedactor`): masks phones, emails, links, Luhn-valid card numbers, optionally @usernames. **Not yet applied to chats**; demo on sample text. May also mask date-like number groups.
- Storage: `Application Support/NYXGram/{event-log,toolkit}.json`, atomic writes, `.bak`, damaged files kept as `.corrupt-<time>`.
- Menu: «More» → NYX Toolkit.

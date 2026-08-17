# Privacy and AI Transmission

- AI is off by default; remote requires explicit opt-in (`ai.enabled` + `ai.remote.enabled`).
- Context is minimized: one finding's bounded snippet (80 lines, 32 KiB), rails facts for that path, git slice, policy reason.
- Inspect before send: `railverdict explain <id> --preview-context --format json`.
- Secret detection: filename blocklist (`.env`, `master.key`, `*.pem`, `id_rsa`, `tmp/`, `log/`) and content patterns (AWS keys, private keys, `ghp_` tokens). Fail-closed for remote.
- `trust: redacted` (default) redacts probable secrets as `[REDACTED]`; `trust: full` blocks the request.
- Provider credentials are read from `RAILVERDICT_AI_API_KEY`/`OPENAI_API_KEY` at invocation and never serialized to output, cache, or logs.
- Prompt injection: repository content is isolated as `UNTRUSTED_REPOSITORY_DATA`; instructions inside are not followed.

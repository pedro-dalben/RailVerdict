# MCP Adapter — RailVerdict

**Observation date:** 2026-08-17 — **Spec:** `2025-11-25` stable — **SDK:** `mcp 1.2` (official Ruby SDK, `modelcontextprotocol/ruby-sdk`) — **Transport:** stdio

MCP is a thin downstream adapter over stable `Check` / `Finding` / `GateResult` / `RepairPacket` contracts. It owns no second policy, analyzer execution, or source-editing engine. RailVerdict remains verifier; external agents remain actors.

## Launch (stdio)

Client launches a subprocess. No daemon, no account, no telemetry, no network for deterministic tools.

```json
{ "command": "bundle", "args": ["exec", "railverdict", "mcp", "serve", "--repository-root", "."] }
```

Manual smoke:

```sh
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
' | bundle exec railverdict mcp serve
echo '{"jsonrpc":"2.0","id":1,"method":"ping"}' | bundle exec railverdict mcp serve
```

`stdout` is exclusively JSON-RPC lines (SDK `StdioTransport` enforces `max_line_bytes 4 MiB`). Diagnostics go to `stderr` or `notifications/message`. On `SIGINT`/`SIGTERM`/EOF, `ProcessRunner.registry.terminate_all` terminates children (pgroup TERM/KILL).

## Repository root

Fixed for the lifetime of the server at startup (`--repository-root` or `Dir.pwd` realpath). All client-supplied paths validated for containment (realpath prefix, no `..` traversal, no absolute escape, symlink escape rejected, UTF-8 scrubbed). No per-request arbitrary `../../etc` / `/` / `/home/other`.

## Tools

All tools are `readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false`. Verification `FAIL` is a successful result (`isError: false` with `gate: FAIL`) — not a protocol error. `INCOMPLETE` is `isError: false` with `gate: INCOMPLETE`. Tool errors (`isError: true`) use `{code, message}`. Unknown tool is a protocol error `-32602`.

| Tool | Input | Returns (`structuredContent`) | Notes |
|---|---|---|---|
| `verify` | `{changed?, base?, config_path?, baseline_path?, waiver_path?}` | `GateResult` (`schema_version`, `completion_status`, `gate`, `policy_status`, `findings`, `analyzer_results`, `operational_failures`, `decision_reasons`, optional `git`/`rails_context`/`baseline`/`comparison`) | If `base` then `changed` required (`invalid_arguments` otherwise). `base` restricted to hex SHA. Calls `Check.execute` under mutex, caches outcome. |
| `list_findings` | `{limit? (1..100 default 50), offset?, severity?, state?, blocking?}` | `{findings:[Finding...], total, limit, offset, truncated, gate, completion_status}` | Filters deterministic, stable `sort_key`, `truncated` explicit. Reuses last `verify` cache or auto-verifies. |
| `get_finding` | `{finding_ref: rv:…|sha256:…}` | `{finding, gate_summary, evidence, git_context, rails_context}` | Exact `id` or `fingerprint`; no fuzzy match. `finding_not_found` / `invalid_arguments`. |
| `build_repair_packet` | `{finding_ref}` | `{packet: RepairPacket v1}` | Calls `Repair::ContextAssembler.build` -> `Repair::Packet`; bounded `256 KiB` / `16 KiB hunk` / `3*80*32KiB` snippets, secret-redacted, `TRUSTED` `instructions` vs `UNTRUSTED_REPOSITORY_DATA`. `stale_target` if unknown. Stored in bounded in-memory LRU (10). |
| `verify_repair` | `{packet_id: sha256:…, changed?, base?}` | `{target_status: fixed|still_present|changed|moved|regressed|incomplete, gate, completion_status, new_blocking_findings, verification_boundary_changed: {config,baseline,waivers,base,source}|false, regressed, gate_result}` | `packet_id` must match prior `build_repair_packet` in session. Re-runs `Check.execute` then `Repair::Verifier.verify`. Never trusts agent claim. Surfaces `verification_boundary_changed`. Required analyzer missing -> `incomplete` even if target vanished. |
| `explain` | `{finding_ref, preview?}` | preview: `{preview:true, manifest}` else `{failure?, analysis?}` | Advisory. `preview` returns `ContextBuilder` manifest `64 KiB` with no network. Otherwise checks `ai.enabled && ai.remote.enabled` else `ai_disabled`. Budgets/secret/redaction enforced. |
| `investigate` | `{limit? 1..3, preview?}` | preview: `{preview:true, manifests:[...]}` else `{results:[{failure?,analysis?}]}` | Same advisory guarantees. `limit` default 3. |

No `exec`, `read_file`, `edit`, `baseline_create`, `waiver` tools. Resources/Prompts not exposed.

## Capability discovery

`initialize` returns `serverInfo {name: railverdict, title: RailVerdict, version}`, `capabilities {tools:{listChanged:false}}`, `instructions` read-only verifier statement, `protocolVersion: 2025-11-25`. `tools/list` enumerates the 7 tools.

## Structured content

Per `server/tools` spec, each `tools/call` returns `{content:[{type:"text", text: serialized JSON}], structuredContent, isError}`. `structuredContent` is canonical versioned JSON; `content` mirrors it for backward compat. Text is UTF-8 scrubbed and bounded. Schemas reuse `schemas/*v1.json` (`result-v1`, `finding-v1`, `repair-packet-v1`, `ai-analysis-v1`).

## Output bounds

`list_findings` capped `100`, `get_finding` context `64 KiB`, packet `256 KiB`. `verify`/`verify_repair` responses capped `256 KiB` (truncated deterministically or `response_too_large` directing to `list_findings`/`get_finding`). Control chars replaced `?`, oversize rejected with `invalid_arguments`. `truncated` flag explicit. JSON never truncated into invalid documents; `gate`/`completion_status`/`policy_status`/`decision_reasons`/`verification_boundary_changed` preserved.

## Analyzer side effects

MCP tools are `readOnlyHint: true` — RailVerdict does not intentionally mutate product source/policy. Analyzers themselves may create `coverage/` files, test caches, or Bundler/tool caches as normal local side effects. RailVerdict executes only analyzers already installed/configured by the target project.

## Cache semantics

`verify` result is cached per server instance; `verify_repair` always re-runs fresh verification. Cache validity checks `config_digest`, `revision`, findings hash, and baseline/waiver file mtimes/sizes; external edits invalidate it. No filesystem watchers or daemon persistence.

## Dependency

`mcp ~> 1.2.0` (>=1.2.0 <1.3.0), protocol `2025-11-25` stable. `outputSchema` is declared via `MCP::Tool::OutputSchema` where supported by the SDK; where the SDK cannot express it, the tool still returns `structuredContent` per `result-v1`/`finding-v1`/`repair-packet-v1`.

## Response serialization

`verify` and `verify_repair` execute under a server-level mutex (`RailVerdict::MCP::Server#synchronized_verification`); `ProcessRunner` registry is not a concurrent verification registry and stdio is synchronous. Verification operations are serialized per MCP server instance.

## Path containment

`config_path`, `baseline_path`, `waiver_path` are all contained within the fixed repository root (`RepositoryRoot.contained?` with realpath). `../` escape, absolute outside paths, symlink escapes, and NUL are rejected as `invalid_arguments` (tool error, not `INCOMPLETE`).

## Errors vs gate

| Situation | Response |
|---|---|
| `invalid_arguments` (types/lengths/NUL/escape/limit/base) | `isError: true, code: invalid_arguments` |
| `finding_not_found` / `stale_target` (unknown `finding_ref`/`packet_id`) | `isError: true` |
| `ai_disabled` | `isError: true` |
| `verify` gate `FAIL` / `INCOMPLETE` | `isError: false`, `structuredContent.gate: FAIL/INCOMPLETE` |
| Unknown tool | protocol `-32602` |
| Internal | `isError: true, code: internal_error` |

Never include backtrace in client response.

## AI privacy

Deterministic tools work offline with zero network. `MCP` existence does not imply AI consent; `OPENAI_API_KEY` presence does not imply AI consent. Remote invocation still requires `ai.enabled && ai.remote.enabled` and `trust: redacted` default; `SecretDetector`/`Redactor`/`Budget` enforced before provider; raw context never cached; never expose provider keys/headers.

## Client configs (generic)

The SDK example uses stdio. For e.g. Claude/Codex, use the launch command above with your client's MCP stdio configuration. No `mcp.railverdict.dev` hosted endpoint exists.

## Protocol/security references

- Spec `2025-11-25` transports (`stdio` newline-delimited, `stdout` purity, `max_line_bytes`), `server/tools` (`tools/list` pagination, `tools/call`, `structuredContent`/`outputSchema` `2020-12`, annotations, `isError` vs protocol errors), `versioning` (supported `2025-11-25` stable, `2026-07-28` RC not targeted).
- SDK `modelcontextprotocol/ruby-sdk` `MCP::Server` + `MCP::Tool` + `StdioTransport` (see `gem contents mcp`).

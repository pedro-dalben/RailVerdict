# BYOA: MCP agent flow

Generic flow for any agent that speaks MCP. No vendor SDK, no credentials, no
provider required for deterministic verification.

## 1. Observe policy and plan

```json
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"verify","arguments":{"changed":true,"base":"<merge-base-sha>"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_engineering_policy","arguments":{}}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_review_packet","arguments":{}}}
```

Read `decision`, `requirements`, `recovery`, and `review.focus`. The packet tells
you what to run, why, what blocked, and what needs a human.

## 2. Distinguish FAIL from INCOMPLETE

- `FAIL` → repair code against the packet's `required` check; see
  `build_repair_packet` for a deterministic target.
- `INCOMPLETE` → restore evidence per `recovery` (run the required analyzer,
  provide git history, generate fresh coverage). Do **not** edit code for
  missing evidence.

## 3. Re-verify after any change, reject stale

```json
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"verify_repair","arguments":{"packet_id":"sha256:…"}}}
```

A receipt, packet, or observation from before your edit is stale. Re-observe;
`verification_required` means run `verify` again, never reuse the old gate.

## 4. Record observations, never approval

```json
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"verify_review_observation","arguments":{"observation":{…}}}}
{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"create_workflow_receipt","arguments":{"observations":[{…}]}}}
```

Observations are `authoritative: false` data. `readiness: ready` requires a
fresh gate plus satisfied requirements; a bound observation never upgrades it.

## 5. Hand review context to the human when required

`REVIEW_REQUIRED` (or `readiness: review_pending`) ends your loop: deliver the
review packet's `review` lane (risk, focus, gaps) to the human. Do not declare
success.

# Review Workflow (1.8)

RailVerdict verifies; you (or your agent) act. Three documents close the loop.

## The loop

```sh
railverdict review show --base main --format json > packet.json
# FAIL        -> repair code; see packet.json -> deterministic.plan
# INCOMPLETE  -> restore evidence; see deterministic.recovery (ordered actions)
# REVIEW_REQUIRED -> review, then record a note (never approval)

railverdict repair <finding-id> --format json > repair-packet.json
# ... edit code outside railverdict ...
railverdict repair verify --packet repair-packet.json --format json

railverdict review observe --observation note.json --format json
railverdict review complete --base main --observation note.json --format json
```

Exits: `0` ready/`PASS`, `1` blocked by gate, `2` blocked by evidence,
`3` review pending. Any nonzero exit is failure; `review_pending` hands the
packet's `review` lane to a human.

## The documents

- **ReviewPacket** (`review-packet-v1`): bounded context for one verification —
  gate projection, analyzer evidence, observed plan (what executed, test scope,
  requirement statuses), policy decision, evidence gaps with ordered recovery,
  plus the review lane (risk, focus, changed surfaces). `packet_id` binds the
  stable core. Context only, never a gate.
- **ReviewObservation** (`review-observation-v1`): an outside note about a
  state — declared author (`human`/`agent`/`ai` + provider), confidence,
  state binding, `authoritative: false` always. Validating proves the note
  refers to fresh state (`valid_bound`), or reports `stale`/`untrusted`/
  `invalid`/`unavailable`. It cannot change any gate or requirement.
- **WorkflowReceipt** (`workflow-receipt-v1`): closure record binding packet,
  policy decision, and validated observations (digests only) to `readiness`
  (`ready`/`blocked_by_gate`/`blocked_by_evidence`/`review_pending`). Refuses
  packet/decision mix-and-match. Reports only.

## Rules for agents

1. Observe policy/plan first (`review show`, `policy`).
2. `FAIL` → repair deterministic targets; `INCOMPLETE` → restore evidence,
   never edit code for missing evidence.
3. Re-verify after every change; reject anything stale.
4. Never declare success without a fresh gate and satisfied requirements.
5. `review_pending` ends your loop — deliver the review lane to the human.

See `examples/workflow/` for MCP, CLI, and human flows.

# BYOA: CLI/JSON agent flow

Same discipline as the MCP flow, over pipes. Parse JSON only; never scrape the
human console for decisions.

```sh
# 1. verify and read the machine contracts
railverdict check --changed --base main --format json > gate.json
railverdict policy --base main --format json > policy.json
railverdict review show --base main --format json > packet.json

# 2. FAIL -> repair against a deterministic target
railverdict repair <finding-id> --format json > repair-packet.json
# ... edit code outside railverdict ...
railverdict repair verify --packet repair-packet.json --format json

# 3. INCOMPLETE -> restore evidence, do not edit code
# packet.json -> deterministic.recovery[] lists ordered actions

# 4. record an observation (still not approval)
railverdict review observe --observation note.json --format json

# 5. close the workflow; readiness decides what you may claim
railverdict review complete --base main --format json \
  --observation note.json > workflow.json
```

Exit ladder: `0` ready/`PASS`, `1` blocked by gate, `2` blocked by evidence,
`3` review pending. Any nonzero exit is failure; `review_pending` means hand
the packet's `review` lane to the human.

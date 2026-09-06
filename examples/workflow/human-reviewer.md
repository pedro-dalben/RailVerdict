# BYOA: human reviewer flow

```sh
railverdict review show --base main
```

```
Review packet: sha256:8bdf… (gate PASS, policy REVIEW_REQUIRED)
Analyzers executed: rubocop, rspec
Requirements:
  [satisfied] req-analyzer-rspec-for-authorization
  [review_required] req-human-review-high
Recovery:
Review risk: HIGH
Review focus:
  1. Migration — schema change
```

Read top-down: gate first, then what the policy demands, then risk-ordered
focus. Titles only on console; full paths live in `--format json`. Evidence
gaps (`Recovery:`) are facts about missing proof, not code suggestions.

When you finish reviewing, record a note (a fact of presence, not a proof of
correctness) and close the loop:

```sh
railverdict review observe --observation note.json
railverdict review complete --base main --observation note.json
```

`review_pending` is the tool telling you the decision is yours. Nothing you
write into `note.json` can turn the deterministic gate green — and that is the
guarantee that keeps your review meaningful.
```

See [`review-observation-v1.json`](review-observation-v1.json) for the note shape.

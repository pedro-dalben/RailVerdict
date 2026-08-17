# AI Intelligence (Phase 06)

AI is optional, advisory, and off by default. `railverdict check` remains offline and deterministic regardless of AI configuration or environment credentials.

## Enabling

```yaml
version: 1.4
mode: strict
analyzers: { rubocop: { enabled: true, required: true } }
ai:
  enabled: true
  mode: explain
  remote:
    enabled: true
    trust: redacted
```

Remote transmission requires both `ai.enabled` and `ai.remote.enabled`. Existence of `OPENAI_API_KEY` alone does not enable AI.

## Preview

```sh
railverdict explain rv:abcd --preview-context --format json
railverdict investigate --preview-context
```

Preview prints the bounded manifest without network.

## Bounds

Max 3 files, 80 lines per file, 32 KiB snippets, 64 KiB manifest, 3 findings per investigate. Budgets enforced before provider.

## Privacy

Filenames like `.env`, `master.key`, `*.pem` are excluded. Content matching probable secrets is redacted or blocks remote transmission in `trust: full`. See `docs/privacy.md`.

## Cache

Disabled by default. When `ai.cache.enabled: true`, validated `AIAnalysis` entries are stored under `.railverdict/cache/ai/` (10 MiB cap, atomic writes). Raw context is never cached.

## Prompt boundary

System instructions are isolated from `UNTRUSTED_REPOSITORY_DATA`. Repository text is treated as data only.

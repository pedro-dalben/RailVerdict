# RailVerdict Architecture

This document is an implementation-independent contract for future RailVerdict runtime work. Phase 0 contains no gem or production runtime scaffold. The repository tree below is **proposed, not present**.

Product scope lives in [PROJECT.md](PROJECT.md), operating invariants in [PHILOSOPHY.md](PHILOSOPHY.md), draft public data and CLI surfaces in [docs/contracts.md](docs/contracts.md), and trust-boundary controls in [SECURITY.md](SECURITY.md).

## Four One-Way Layers

```text
1. Evidence collection
   external tools -> AnalyzerResult facts
                         |
                         v
2. Deterministic verification core
   normalize -> compare -> policy -> GateResult
                         |
                         v
3. Optional intelligence
   reads immutable results -> advisory attachment
                         |
                         v
4. Consumers
   CLI | CI | GitHub | coding agents | future MCP
```

Runtime evidence moves from collection toward the core; decisions and read models move outward. Authority does not move with presentation:

1. **Evidence collection owns facts.** It records what a tool ran, observed, and returned, including unavailable, unsupported, timed-out, failed, truncated, and malformed states. An analyzer never decides whether a merge is allowed.
2. **The deterministic verification core owns normalization and policy.** Policy evaluation alone creates policy decisions and the immutable `GateResult`. Incomplete required evidence cannot be represented as an empty successful run or a trustworthy `PASS`.
3. **Optional intelligence is downstream and read-only.** AI may read an immutable finding or `GateResult` snapshot and attach advice. It cannot reinterpret, weaken, replace, or recalculate the gate.
4. **Consumers project or act on existing results.** CLI, CI, reporters, GitHub, coding agents, and future MCP transport or render core results. None owns a second gate engine.

## Dependency Direction

Source dependencies point toward stable core contracts, never toward delivery mechanisms. Evidence adapters implement core-owned ports and return core-owned result values. Reporters, platform adapters, and optional intelligence call application services and consume immutable core values. The core imports no CLI renderer, AI provider, GitHub type, MCP type, or analyzer implementation.

This separates two directions that are easy to confuse:

- **Runtime data:** evidence flows into the core; results flow outward.
- **Source code:** concrete adapters depend on core contracts; core contracts do not depend on adapters.

## Future Responsibilities

The names below describe proposed responsibilities, not implemented classes or public APIs.

| Future concept | Owns | Must not own |
|---|---|---|
| `Check` application service | Deterministic orchestration and ordering | CLI rendering, analyzer-specific parsing, AI calls |
| `Configuration` | Strict data loading, validation, defaults, effective-value provenance | Executable configuration or hidden policy overrides |
| `RunContext` | Repository root, revision scope, Rails/tool metadata, deterministic inputs | Mutable global state |
| Analyzer adapter | Availability/version checks, argv construction, native-output parsing | Policy, baselines, reporting |
| `AnalyzerResult` | Complete invocation facts, execution status, and evidence status | Gate authority |
| Process boundary | Executable-plus-argv lifecycle, bounded I/O, timeout, cleanup | Analyzer-specific exit interpretation |
| `Finding` and normalization | Analyzer-independent evidence with origin and provenance | Blocking or `PASS`/`WARN`/`FAIL` authority |
| Fingerprint, baseline, and waiver work | Versioned identity, comparison facts, explicit exceptions | Silent baseline mutation or evidence removal |
| Policy evaluation | Evidence-to-decision rules and the sole creation of `GateResult` | Analyzer execution, AI judgment, presentation |
| `GateResult` | Immutable completed or incomplete run result serialized by the versioned result contract | Rendering, transport, provider credentials |
| Console and JSON reporters | Pure projection of `GateResult` | Mutation, policy, network access |
| `AIAnalysis` | Optional schema-validated advisory content | Gate changes or code editing |
| `RepairPacket` | Deterministic bounded evidence and argv verification commands | Applying repairs or granting permissions |
| GitHub and MCP adapters | Platform/protocol mapping over application services | Duplicate policy or analyzer engines |

The draft contract details remain owned by [docs/contracts.md](docs/contracts.md); this document owns only responsibility and dependency boundaries.

## Proposed Phase 1 One-Gem/One-Process Shape

The first runtime structure should be one gem and one process. The following is a **proposed, not present** Phase 1 tree; comments name the behavior that would justify each path.

```text
rail_verdict.gemspec                 # Phase 1: one gem package
exe/railverdict                      # Phase 1: one CLI process
lib/                                 # Phase 1: runtime namespace
├── rail_verdict.rb                  # Phase 1: public load boundary
└── rail_verdict/
    ├── version.rb                   # Phase 1: runtime/report identity
    ├── cli.rb                       # Phase 1: command and exit mapping
    ├── check.rb                     # Phase 1: vertical orchestration
    ├── configuration.rb             # Phase 1: strict configuration
    ├── run_context.rb               # Phase 1: deterministic inputs
    ├── process_runner.rb             # Phase 1: external process boundary
    ├── contracts/                   # Phase 1: Finding, AnalyzerResult, GateResult
    ├── analyzers/                   # Phase 1: one narrow RuboCop adapter
    ├── verification/                # Phase 1: normalization and minimal policy
    └── reporters/                   # Phase 1: console and JSON projection
schemas/                             # Phase 0 drafts; Phase 1 runtime contract evidence
```

The tree is a planning boundary, not scaffolding authorization. Phase 1 should create a path only when its vertical behavior needs it; several concepts may remain small immutable values inside their owning contract rather than receiving files or base classes.

## Explicit Exclusions

The proposed v1 architecture has no database, daemon, Rails engine, plugin marketplace, multiple gems, hosted control plane, or mandatory network service. It also excludes:

- an `intelligence/` directory before Phase 6 has real optional-AI behavior;
- GitHub-specific or MCP-specific core types;
- a full semantic code graph;
- analyzer bundling or silent installation;
- a second policy implementation in a reporter or adapter;
- directories, interfaces, factories, registries, or extension abstractions without an owning behavior.

Later phases may add bounded behavior under [ROADMAP.md](ROADMAP.md), but they do not justify empty Phase 1 structure.

## External Process Boundary

Future analyzer execution must use a trusted executable plus separate argv entries, a verified working directory, bounded concurrent stdout/stderr handling, timeouts, explicit failure states, process-tree cleanup, and a minimal environment. This reduces command-injection and resource-exhaustion risk.

Executable-plus-argv isolation is **not an operating-system sandbox**. It does not stop a selected executable from exercising the permissions of its process. Supported operating systems, containment limits, environment allowlists, byte caps, timeout defaults, and process-tree behavior require Phase 1 evidence and remain governed by [SECURITY.md](SECURITY.md).

## Decision Links

- [ADR 0001: deterministic PASS/FAIL](docs/adr/0001-deterministic-pass-fail.md)
- [ADR 0002: external analyzer execution](docs/adr/0002-external-analyzer-execution.md)
- [ADR 0003: canonical Finding](docs/adr/0003-canonical-finding.md)
- [ADR 0004: versioned schemas](docs/adr/0004-versioned-schemas.md)
- [ADR 0006: no-new-debt](docs/adr/0006-no-new-debt.md)
- [ADR 0007: advisory AI](docs/adr/0007-advisory-ai.md)
- [ADR 0008: remote AI opt-in](docs/adr/0008-remote-ai-explicit-opt-in.md)
- [ADR 0009: GitHub as an adapter](docs/adr/0009-github-as-an-adapter.md)
- [ADR 0010: canonical CLI and JSON](docs/adr/0010-cli-and-json-canonical.md)
- [ADR 0011: MCP as an adapter](docs/adr/0011-mcp-as-an-adapter.md)

These decisions ratify boundaries only. Their implementation and proof belong to the owning phases in [ROADMAP.md](ROADMAP.md).

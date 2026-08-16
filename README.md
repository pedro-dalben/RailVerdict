# RailVerdict

**Evidence before merge.**

RailVerdict is a fully open-source, local-first verification framework for Ruby on Rails applications. Its intended contract is to collect evidence from established tools, normalize that evidence, apply repository-owned policy and baselines, and return a deterministic merge gate for humans, CI systems, and coding agents.

## Current Status

RailVerdict is a documentation-only foundation in Phase 0. Publication is blocked pending documented searches in every launch jurisdiction, including Brazil, and qualified trademark review; the exact unresolved record is in [the foundation record](docs/foundation.md).

There is no published gem, CLI, analyzer integration, GitHub adapter, MCP adapter, AI integration, or other RailVerdict runtime behavior yet. RailVerdict is not a SaaS or hosted service. AI is optional and advisory by design, and it is currently unimplemented.

## Foundation

- [Product definition and competitive position](PROJECT.md)
- [Operating philosophy](PHILOSOPHY.md)
- [Architecture contract](ARCHITECTURE.md)
- [Name, identity, and publication status](docs/foundation.md)
- [Analyzer and support proposal](docs/analyzers.md)
- [Draft public contracts](docs/contracts.md)
- [Security and information-firewall policy](SECURITY.md)
- [Public roadmap](ROADMAP.md)
- [Architecture decision records](docs/adr/)

## Draft Schemas and Synthetic Examples

- [Finding schema](schemas/finding-v1.schema.json) and [Finding example](examples/finding-v1.json)
- [Configuration schema](schemas/configuration-v1.schema.json) and [configuration example](examples/configuration-v1.yml)

These are pre-implementation drafts, not compatibility or support promises.

## Legal

- [Apache License 2.0](LICENSE)
- [NOTICE](NOTICE)
- [Trademark policy](TRADEMARKS.md)

The software license and trademark policy are separate. Nothing in the current identity decision authorizes publication or claims trademark clearance.

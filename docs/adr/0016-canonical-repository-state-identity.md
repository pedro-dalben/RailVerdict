# ADR 0016: Canonical Repository State Identity

Status: Accepted

Decision date: 2026-08-24

Implementation status: Implemented in RailVerdict 1.2. `RailVerdict::RepositoryState` produces a deterministic, content-bound identity (`sha256:` digest) over the observable verification inputs of a Git working copy.

## Context

Verification evidence is only meaningful for the exact repository state that analyzers observed. Before 1.2 the only freshness algorithm was private to the MCP cache, conflated concerns, and used process-local Ruby hashing. Verification receipts (ADR 0017), stale detection, MCP cache freshness, and future agent-protocol consumers all need one shared canonical identity; maintaining parallel algorithms would let them disagree.

## Decision

One canonical `RepositoryState` identity v1 is the single source of truth for "which observable state was verified". It binds:

- HEAD commit SHA (or an explicit `unborn` marker);
- the full Git index snapshot via bounded `git ls-files -s -z` bytes, so staged-only and mixed staged/unstaged states are distinguished;
- the worktree delta from `git status --porcelain=v2 --no-renames -z --untracked-files=all`, with per-path content identity (SHA-256 of bytes) for modified, untracked, type-changed, and symlink entries, and explicit markers for deletions;
- content digests of the resolved RailVerdict configuration, baseline, and waivers files.

The digest is `sha256:<64 hex>` over explicit canonical JSON with sorted keys and explicitly sorted arrays. It excludes absolute checkout paths, hostnames, users, inode/mtime metadata, PIDs, randomness, and timestamps: two identical checkouts at different paths produce identical digests.

Operationally bounded: committed state is represented by the HEAD commit identity, the index by its object listing, and only dirty/untracked files are content-hashed. Exceeding bounds (status output, dirty-path count, per-file size), unreadable files, invalid encodings, or any Git failure yields an explicit unavailable result with a reason — never silent omission.

## Consequences

- Receipt freshness and MCP cache freshness must both consume this identity; they may not fork the algorithm.
- mtime-only changes do not affect the identity.
- Restoring exact original bytes restores identity (content-addressed, not history-addressed).
- Unavailable state fails receipt issuance and freshness checks closed.
- The identity is deterministic integrity data; it proves nothing about who computed it.

## Related Documents

- [ADR 0017](0017-verification-receipts.md)
- [docs/agent-verification.md](../agent-verification.md)

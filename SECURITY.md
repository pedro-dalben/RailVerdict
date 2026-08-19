# Security Model

## Status and scope

This document is RailVerdict's canonical security contract. Phase 0 defines required controls and evidence ownership; it does not claim that the runtime, CI, AI, or release controls already exist. The layer and authority boundaries in [ARCHITECTURE.md](ARCHITECTURE.md) remain authoritative, and [ROADMAP.md](ROADMAP.md) assigns implementation and release gates to Phases 1 through 9.

RailVerdict's highest-risk failure is a false PASS: required evidence is absent, stale, malformed, partial, or otherwise untrustworthy, but the result appears complete. Gate status and evidence completeness are separate facts. A required analyzer that does not reach a supported, successful, complete terminal state cannot produce a trustworthy `PASS`.

The active project policy blocks a phase, merge gate, or release gate on every unresolved **HIGH** threat assigned to that gate. Every HIGH threat blocks its owning gate until the required control is evidenced. A HIGH threat may be mitigated or transferred to a named competent authority, but it may not be accepted. Documentary controls do not close a runtime threat; only the evidence named below does.

## Assets

| Asset | Required protection |
|---|---|
| Gate and policy decisions | `PASS`, `WARN`, and `FAIL` must come only from complete declared evidence and versioned deterministic policy. |
| Evidence and run manifests | Analyzer identity, version, argv, terminal state, scope, truncation state, source revision, and artifact digests must be complete and auditable. |
| Baselines, fingerprints, policies, and waivers | Existing debt cannot be silently enlarged, mis-correlated, reclassified, waived broadly, or changed by an ordinary check. |
| Repository source and secrets | Source, configuration, Git data, diagnostics, temporary files, caches, reports, and future AI context must not disclose sensitive material. |
| CI and publisher credentials | Fork code, repository-controlled scripts, analyzers, caches, and artifacts must not receive write tokens, remote-AI credentials, or publisher authority. |
| Release and artifact identity | The tested, checksummed, attested, published, and installed gem must be the same build from the recorded source revision. |
| Product identity and assurance claims | Dated technical evidence, legal conclusions, ASVS mappings, and implementation status must not be overstated. |

## Adversaries and failure actors

- An accidental contributor who misconfigures an analyzer, records incomplete evidence, changes a baseline incorrectly, grants a broad waiver, or publishes a stale artifact.
- A malicious contributor or fork author who controls repository content, paths, configuration, test code, analyzer output, Git metadata, pull-request text, workflow changes, caches, and untrusted artifacts.
- A compromised analyzer, plugin, dependency, GitHub Action, runner, remote-AI provider, registry, or maintainer account.
- A resource or cost abuser who creates pathological inputs, excessive output, process trees, slow scans, archive expansion, or repeated paid-provider requests.

## Trust Boundaries

| Boundary | Untrusted side | Trusted decision or asset | Required rule |
|---|---|---|---|
| Repository | Source, configuration, paths, symlinks, Git metadata, fixtures, comments, and contribution text | Parsed configuration, repository scope, and canonical evidence | Treat all repository-controlled material as data; validate structure, paths, size, encoding, and scope before use. |
| Analyzer and test process | Executables, plugins, dependencies, exit codes, signals, stdout, stderr, files, and descendants | `AnalyzerResult`, host resources, and diagnostics | One bounded process boundary captures facts; each adapter interprets only its own documented version and output contract. |
| Host operating system | Child processes executing with local user authority | Filesystem, environment, descriptors, CPU, memory, disk, and network | Minimize inherited authority and bound resources; document platform-specific limits. |
| Optional remote AI | Selected repository context and provider response | Source confidentiality and deterministic `GateResult` | AI is off by default, transmission is explicit and inspectable, and all repository/model text remains untrusted advisory data. |
| CI and forks | Fork code, event fields, scripts, caches, and artifacts | Secrets, write tokens, trusted branch state, release environments, and remote-AI credentials | Untrusted execution is secret-free and least-privileged; privileged jobs never execute or trust fork-controlled material. |
| Release and registry | Tags, workflows, dependencies, build outputs, attestations, and registry responses | Publisher identity and public gem integrity | Build once, verify one digest chain, and publish that exact protected artifact. |
| Legal and public assurance | Registry observations, automated checks, and draft controls | Publication authorization and public security claims | Preserve limitations; qualified reviewers own legal conclusions, and automated evidence cannot claim certification or clearance. |

## Subprocess containment limit

Argument/process isolation is not an operating-system sandbox; hostile analyzers and tests still execute with the caller's authority. Executable-plus-argv invocation prevents shell interpretation of argument strings, but it does not isolate the filesystem, network, credentials, kernel, or other processes. Public-fork execution therefore also needs ephemeral, secret-free, least-privileged infrastructure in Phase 4. Any future sandbox claim requires a dedicated design, per-platform proof, and a new security review.

## Severity and disposition

| Term | Meaning |
|---|---|
| HIGH | Could create a false `PASS`, expose protected material or privileged credentials, compromise publication, or materially corrupt the trust chain. It blocks the owning phase or release until evidenced. |
| MEDIUM | Could mislead users, reduce availability, create bounded cost, or weaken defense in depth. It must have an owner and tracked treatment. |
| LOW | Limited documentary or Phase 0 exposure with no current production surface. It may be accepted only with the stated scope and re-evaluation trigger. |
| Mitigate | RailVerdict must implement and verify the named control. |
| Transfer | A named external authority owns the decision that engineering cannot make, while RailVerdict retains the fail-closed gate. |
| Accept | The documented residual risk is tolerated only within the stated current scope. HIGH risks cannot use this disposition. |

## STRIDE Threat Register

| ID | STRIDE category | Threat and affected asset | Severity | Disposition | Required Phase 0 control | Residual limitation | Required verification evidence | Owning phase |
|---|---|---|---|---|---|---|---|---|
| T-01 | Tampering / Repudiation | An unavailable or unsupported required analyzer is normalized as zero findings, creating a false `PASS`. | HIGH | Mitigate | Completeness is separate from gate status; required evidence must be supported, successful, complete, and version-recorded. | Tool-specific exit and output meanings cannot be inferred by a shared runner. | Missing executable, unsupported version, and unknown-version fixtures produce explicit incomplete results and never `PASS`. | Phase 1 core semantics; Phase 2 every adapter. |
| T-02 | Tampering | Stale, malformed, truncated, partial, invalidly encoded, or internally inconsistent output is accepted as complete evidence. | HIGH | Mitigate | Strict versioned parsing and invariants; empty success is distinct from missing evidence; truncation is terminal and explicit. | A valid schema alone cannot prove freshness or expected suite/worker completeness. | Mutation corpus covers empty, trailing, malformed, oversized, partial, stale-revision, missing-worker, and valid-zero cases. | Phase 1 parser contract; Phase 2 evidence fixtures; Phase 4 Git scope. |
| T-03 | Tampering / Elevation of Privilege | Hostile paths or executable configuration escape the repository, load objects, or alter policy silently. | HIGH | Mitigate | Data-only strict configuration, unknown-key rejection, verified repository root, repository-relative paths, and explicit precedence. | Symlink and platform path semantics require operating-system tests. | Fixtures cover traversal, absolute paths, symlink escape, object tags, aliases, encoding, and alternate working directories. | Phase 1. |
| T-04 | Spoofing / Information Disclosure | Analyzer output uses control characters, forged lines, invalid encoding, oversized fields, or unsafe paths to mislead consoles, logs, JSON, or downstream agents. | HIGH | Mitigate | Treat fields as data; validate encoding/schema/path; bound fields; escape control characters; serialize JSON; retain bounded raw diagnostics separately. | A normalized display cannot make the analyzer itself trustworthy. | Fuzz corpus covers ANSI, CRLF, bidi/zero-width controls, invalid UTF-8, traversal, URIs, deep nesting, and oversized fields. | Phase 1 reporters; Phase 2 adapters. |
| T-05 | Elevation of Privilege / Tampering | Repository-controlled input reaches a shell or changes executable/option structure. | HIGH | Mitigate | A trusted executable plus separate argv elements, no shell strings, adapter-owned option structure, and `--` before paths where supported. | Direct execution still runs the selected executable with caller authority. | Injection corpus proves literal delivery of spaces, quotes, metacharacters, substitutions, newlines, leading dashes, Unicode, and rejected NUL. | Phase 1. |
| T-06 | Denial of Service | A child hangs, floods stdout/stderr, fills memory/disk, forks descendants, survives interruption, or leaves temporary state. | HIGH | Mitigate | Bounded concurrent stdout/stderr draining, independent byte limits, monotonic deadlines, process groups, bounded `TERM`/`KILL`, pipe closure, child reaping, concurrency/resource limits, and `ensure` cleanup. | `SIGKILL`, host failure, and some platform controls cannot guarantee cleanup; degraded controls must be explicit. | Timeout, simultaneous-pipe, grandchild, ignored-signal, output-limit, resource-limit, interruption, and residue tests pass on every supported OS. | Phase 1 runner; Phase 2 adapter budgets. |
| T-07 | Information Disclosure | Children inherit credentials, sockets, descriptors, locale, or nondeterministic environment values, or diagnostics echo them. | HIGH | Mitigate | Minimal documented environment, closed nonstandard descriptors, no secret values in argv/cache/reports, and redaction before persistence or transmission. | Some analyzers may need narrowly documented environment exceptions. | Canary values are absent from child environment, captures, JSON, cache, temporary files, and future AI requests. | Phase 1; Phase 6 transmission boundary. |
| T-08 | Tampering / Repudiation | A baseline absorbs new debt, an ordinary check mutates it, or a broad/expired waiver silently suppresses findings. | HIGH | Mitigate | Checks are read-only; baseline creation is explicit, atomic, and complete-run-only; waivers target exact versioned fingerprints with owner, reason, creation, UTC expiry, and visible state. | Git review does not by itself prove the source run was complete or the fingerprint algorithm compatible. | Baseline diffs, poisoned-run rejection, no-write checks, expiry boundaries, orphaned/over-broad waiver cases, and migration vectors. | Phase 3. |
| T-09 | Information Disclosure / Tampering | Optional AI transmits source or secrets without meaningful consent, follows repository prompt injection, or returns persuasive invalid output that changes objective truth. | HIGH | Mitigate | AI off by default; deterministic minimal context and transmission manifest; secret exclusion/redaction fail closed; instructions separated from untrusted data; no write tools; strict response schema; advisory-only output. | Prompt injection cannot be perfectly filtered, and provider retention remains external. | Secret canaries, injection cases, context snapshots, invalid responses, provider failures, and AI-on/off gate equivalence. | Phase 6. |
| T-10 | Denial of Service | Adversarial contexts or retries create unbounded provider cost, latency, or cache growth. | MEDIUM | Mitigate | Enforce request, finding, input, output, elapsed-time, retry, monetary, and storage limits before invocation; never use paid AI for untrusted forks. | Provider-side accounting and price changes remain external inputs. | Mock-provider ceiling, concurrent accounting, retry-cap, oversized-context, cache-isolation, and budget-exhaustion tests. | Phase 6. |
| T-11 | Elevation of Privilege / Information Disclosure | A privileged workflow checks out or executes fork code, restores fork caches, trusts fork artifacts, or exposes write/publisher/AI credentials. | HIGH | Mitigate | Fork verification uses unprivileged secret-free execution and read-only permissions; privileged jobs process only narrowly validated data and never execute fork-controlled material. | Third-party runner and platform compromise remain outside application containment. | Hostile-fork exercise attempts token, secret, cache, artifact, and event-field exfiltration; permission snapshots and trigger lint pass. | Phase 4. |
| T-12 | Tampering / Spoofing | A compromised, stale, or confused dependency or action enters the trusted build or impersonates an expected package. | HIGH | Mitigate | Reviewed dependency identity/source/license, lockfile and frozen install, dependency review, third-party Actions pinned to reviewed full SHAs, and risk-based update deadlines. | Pinning preserves reviewed code but does not prove that code is benign. | Workflow pin scanner, dependency inventory, clean-room locked install, source/maintainer review, and vulnerability response evidence. | Phase 4 CI; Phase 9 release. |
| T-13 | Tampering / Repudiation | The tested artifact differs from the checksummed, attested, published, or installed gem, or attestation is treated as proof of safety. | HIGH | Mitigate | Protected tag/environment, build once, inspect/test/install the exact gem, one recorded digest and source revision, protected short-lived publishing identity, and separate security/provenance gates. | A valid attestation can accurately describe a malicious build. | Negative provenance-policy tests plus matching source revision, contents manifest, digest, tests, checksum, attestation subject, registry artifact, and clean-install smoke. | Phase 9. |
| T-14 | Information Disclosure | Private source, identifiers, operational details, or matched detection values enter source, history, diagnostics, reports, or release artifacts. | HIGH | Mitigate | Synthetic-only public material, external private detection input, non-echoing reports, complete surface accounting, and zero unresolved matches before publication. | Automated secret or pattern scanning cannot prove origin or absence. | Current tree/history review in Phase 0; full gem/archive/media/documentation/release/CI artifact scan and manual review in Phase 9. | Phase 9, governed by the Phase 0 information firewall below. |
| T-15 | Spoofing | Dated registry results, qualified legal conclusions, implementation evidence, or ASVS use is overstated as name clearance, deployed controls, or certification. | MEDIUM | Transfer | Preserve dates, limitations, unresolved status, and evidence owner; publication remains blocked until qualified review; describe ASVS only as a control catalog. | Engineering checks cannot determine confusing similarity, jurisdictional rights, or certify a non-web CLI against ASVS. | Named reviewer, jurisdiction, scope, evidence, date, and conclusion; implemented controls retain phase-specific proof. | Phase 9 publication revalidation; qualified legal reviewer. |
| T-16 | Tampering | Phase 0 documentation accidentally creates runtime, workflow, release, AI, MCP, or package surfaces that have not passed their owning security gate. | LOW | Accept | Phase 0 creates contracts only and applies symmetric prohibited-path checks. | Documentation can still be incomplete or misunderstood. | No-production scope guard and document acceptance checks pass; re-evaluate when Phase 1 creates runtime paths. | Phase 0 only; expires at Phase 1. |

## Required Control Register

| Control | Obligation | Evidence owner |
|---|---|---|
| C-01 Fail-closed evidence | Required evidence has explicit availability, supported version, complete terminal state, freshness, and invariant checks; any failure remains incomplete and cannot `PASS`. | Phases 1–2, with Git scope in Phase 4. |
| C-02 Untrusted data handling | Configuration, repository data, analyzer output, Git data, event fields, and model output are validated, bounded, and rendered only as data. | Phases 1, 2, 4, and 6. |
| C-03 Process lifecycle | Fixed executable plus argv, verified directory, minimal environment, closed descriptors, concurrent bounded I/O, monotonic timeout, process-tree termination, reaping, and cleanup. | Phase 1. |
| C-04 Baseline and waiver authority | Ordinary checks are read-only; only a complete trusted run may create an atomic baseline; exact waivers remain visible and expire deterministically. | Phase 3. |
| C-05 Remote-AI boundary | Explicit opt-in and manifest, minimal context, secret fail-closed behavior, injection isolation, strict advisory output, budgets, and cache separation. | Phase 6. |
| C-06 Fork least privilege | Fork code has no secrets, write token, publisher identity, internal persistent runner, or remote-AI credential; privileged workflows execute no fork-controlled material. | Phase 4. |
| C-07 Supply-chain integrity | Review dependency and action identity, source, license, transitive changes, lock state, vulnerabilities, and Action SHAs before trusted use. | Phases 4 and 9. |
| C-08 Build-once publication | Build, test, inspect, checksum, attest, publish, and install one immutable artifact under protected short-lived publisher authority. | Phase 9. |
| C-09 Information firewall | Public material is synthetic and English-only; private patterns stay outside Git; non-echoing scans account for every required surface and unresolved matches block publication. | Phase 0 policy; Phase 9 enforcement. |
| C-10 Honest assurance | Draft, implemented, verified, certified, legally reviewed, and not applicable remain distinct states with named evidence. | Every phase; Phase 9 release review. |

## OWASP ASVS 5.0.0 Level 1 mapping

[OWASP ASVS 5.0.0](https://github.com/OWASP/ASVS/tree/v5.0.0) is a web-application verification standard. RailVerdict uses applicable Level 1 requirements as a control catalog; this mapping is not certification, does not make RailVerdict a web application, and does not prove implementation. Identifiers are version-qualified because ASVS chapter and requirement numbers can change.

| ASVS 5.0.0 Level 1 requirement | RailVerdict application | Owning evidence |
|---|---|---|
| `v5.0.0-1.2.5` — protect against OS command injection and use parameterized OS calls | C-03 requires a trusted executable plus separate argv elements and forbids interpolated shell strings. | Phase 1 injection corpus and process-runner tests. |
| `v5.0.0-2.1.1` — document validation rules against expected structures | Strict configuration, analyzer, schema, path, output, and artifact expectations are versioned and documented. | Phases 1–2 contract fixtures. |
| `v5.0.0-2.2.1` and `v5.0.0-2.2.2` — positive validation for security decisions at a trusted layer | Required evidence states, versions, schema, limits, and policy inputs are validated before deterministic policy acts. | Phase 1 core tests and Phase 2 adapter conformance. |
| `v5.0.0-5.2.1` and `v5.0.0-5.2.2` — bound accepted file size and validate decision-relevant type/content | Evidence, archives, media, reports, and release artifacts need byte/count limits and content classification before they affect a gate. | Phase 1 evidence limits; Phase 9 release-surface tests. |
| `v5.0.0-5.3.2` — construct file paths from trusted data or strictly validate untrusted names | Repository paths remain normalized, repository-relative, and contained; output locations cannot be repository-controlled escapes. | Phase 1 path and symlink corpus. |
| `v5.0.0-8.1.1` — document function- and data-specific authorization rules | C-06 documents which fork, trusted CI, maintainer, and publisher contexts may access code, artifacts, tokens, and release functions. | Phase 4 permission snapshot; Phase 9 protected release review. |
| `v5.0.0-8.2.1`, `v5.0.0-8.2.2`, and `v5.0.0-8.3.1` — restrict functions/data to explicit permission at a trusted layer | Untrusted jobs cannot publish, write, obtain secrets, or promote their own code/artifacts; trusted enforcement is outside attacker-controlled repository logic. | Phase 4 hostile-fork tests; Phase 9 publisher controls. |
| `v5.0.0-15.1.1` and `v5.0.0-15.2.1` — define risk-based third-party remediation times and enforce them | C-07 requires reviewed dependencies/actions plus documented update and vulnerability response deadlines. | Phase 9 dependency inventory and release review. |
| `v5.0.0-15.3.1` — return only required data fields | Diagnostics, provenance reports, AI manifests, and public evidence expose only the minimum safe metadata, never environments, credentials, or matched private values. | Phases 1, 6, and 9 non-disclosure tests. |

ASVS V13 Configuration, V14 Data Protection, and V16 Security Logging and Error Handling remain useful broader categories. Their most relevant ASVS 5.0.0 requirements for RailVerdict's data classification and log-injection concerns are Level 2 rather than Level 1, so this document does not mislabel them as Level 1 evidence. V3, V4, V6, V7, V9, V10, and V17 are currently not applicable because RailVerdict has no web frontend, hosted API, accounts, sessions, product tokens, OAuth surface, or WebRTC. V12 becomes applicable only if Phase 6 remote AI or Phase 9 publication communication is implemented; V11 applies to standard digest/signature use in Phases 3 and 9, without custom cryptography.

## Residual limits and review triggers

- Process controls reduce injection, leakage, orphaning, and resource risk; they do not sandbox hostile code.
- A deterministic result is trustworthy only for its declared evidence, versions, limits, repository scope, and policy. Optional evidence remains visibly absent.
- Secret scanning, schemas, checksums, and attestations each prove a narrow property; none substitutes for provenance review, dependency review, or qualified legal judgment.
- Phase 4 must reopen this model before adding public-fork CI. Phase 6 must reopen it before remote transmission. Phase 9 must reopen it before building or publishing any release artifact.

## Contact

- **Security contact:** dev@pedrodalben.com.br
- **Legal/trademark contact:** dev@pedrodalben.com.br
- **Repository:** https://github.com/pedro-dalben/RailVerdict
- **Owner / copyright holder:** Pedro Dalben

To report a vulnerability, email the security contact with a description, affected version, and reproduction steps. Do not open a public issue for sensitive reports.

Trademark/name qualified review remains unresolved; see docs/foundation.md and TRADEMARKS.md.

## Information Firewall

The information firewall protects public provenance, language consistency, and non-disclosure across the repository and every future release surface. It is a publication control, not a claim that automated scanning can prove authorship or language semantics.

### Allowed public provenance

Public material must be freshly authored for RailVerdict or derived from a source whose reuse is explicitly documented and permitted. Examples, fixtures, screenshots, sample output, schemas, and demonstrations must be synthetic, generic, and created from scratch using public-domain concepts such as a library, book catalog, store, issue tracker, or project board. Public examples must not be sanitized or renamed copies of a private system.

### Prohibited provenance

The repository, its history, generated artifacts, caches, reports, and release materials must not contain private:

- source code, data, credentials, configuration, environment values, or database content;
- names, identifiers, domain terms, customer or user details, or partner details;
- business rules, data shapes, architecture, infrastructure, security findings, or operational procedures;
- fixtures, metrics, timestamps tied to private operations, screenshots, images, media, or metadata;
- logs, prompts, model context, model responses, issues, pull requests, commit text, paths, branches, internal URLs, or repository details;
- replicas, translations, summaries, transformations, or other derived material that preserves distinctive private structure or meaning.

No private value may be committed for use as a detector, example, test case, exception, explanation, or scan proof. Renaming, redacting, hashing selected fields, or removing credentials does not make a private artifact synthetic.

### Authorized historical attribution exception

RailVerdict may use the literal name `IntegrarPlus` only in a concise,
high-level historical attribution that says engineering experience with that
private Rails application partly motivated RailVerdict, or in provenance-policy
documentation defining this exception. This exception authorizes no source,
schema, model/controller/service name, business rule, clinical or patient
detail, production value, URL, path, branch, issue, log, metric, prompt,
security finding, infrastructure detail, credential, environment value,
customer/user/employee data, screenshot, or private architecture information.
Technical examples, schemas, fixtures, and tests remain synthetic.

### English-only public content

English-only applies to source code, identifiers, comments, logs, messages, documentation, schemas, examples, configuration keys, scripts, workflows, templates, issue and pull-request templates, commits, release notes, changelogs, reports, and artifact metadata.

An internationalization exception is allowed only after an actual fixture needs it. Each excepted file must be listed individually in a reviewed manifest with its path, purpose, language, owner, and review date. A directory, extension, generated-file class, or free-form glob cannot be exempted. No such manifest or exception is implied by this policy.

Language heuristics are defense in depth, not complete language proof. ASCII-only non-English prose, mixed identifiers, transliteration, generated metadata, and semantic drift can evade automated detection; manual review remains required.

### Required scan surfaces

| Surface | Required scope | Phase 0 evidence state | Phase 9 release obligation |
|---|---|---|---|
| Tracked tree | Every tracked public file at the exact candidate revision, including source, documentation, schemas, examples, templates, configuration, and repository metadata | Required now; `not run` when the external private pattern corpus is unavailable | Rescan the exact protected release revision. |
| Git history | Every reachable object across all Git refs, including deleted or renamed content and commit/tag metadata | Required now; `not run` when the external private pattern corpus is unavailable | Rescan all refs immediately before publication. |
| Generated gem | The exact `.gem` contents, filenames, metadata, packaged docs, licenses, and embedded files | `not applicable` while no gem exists; never `passed` by absence | Scan the build-once gem and bind the report to its digest. |
| Source and release archives | Every source archive, release archive, compressed member, filename, and archive metadata | `not applicable` while no archive exists | Scan each exact archive and its expanded bounded contents. |
| Images and media metadata | Image/audio/video/document content, filenames, embedded text, comments, thumbnails, geolocation, authorship, and other metadata | Classify anything present in the tree/history; absent future media is `not applicable` | Scan every release-hosted media asset and its metadata. |
| Documentation and release notes | Public docs, generated docs, API/reference output, changelogs, release notes, and publication descriptions | Repository documentation is included in tree/history review; release notes are `not applicable` until created | Scan the exact rendered and packaged documentation and notes. |
| CI caches and CI artifacts | Cache keys/manifests plus every retained artifact, report, log bundle, coverage export, package, and downloaded handoff | `not applicable` until these surfaces exist; do not infer cleanliness from no workflow | Enumerate and scan every artifact used or retained by release CI; uninspectable caches cannot support publication. |
| Installed-artifact manifest | Files, paths, modes, metadata, and digest produced by installing the exact candidate gem in a clean location | `not applicable` while no installable gem exists | Compare the installed manifest and digest chain with the tested and published artifact. |

“Not applicable” means the named artifact class does not exist for that candidate. “Not run” means the surface exists or is required but the scanner, private corpus, access, or review evidence is missing. Neither state is a pass. A required surface may be marked `passed` only when its exact revision or digest, scanner version, external corpus version, results, exceptions, and reviewer are recorded with zero unresolved matches.

### External private-pattern input

The private detection corpus is maintainer-controlled input stored outside Git, outside generated artifacts, outside CI caches shared with untrusted jobs, and outside public reports. It must not be embedded in command lines, process listings, source files, fixtures, workflow definitions, logs, or exception records. Access is limited to the reviewers performing the scan.

A non-echoing scan interface must accept the repository or artifact target, the external pattern file, and an explicit surface list as separate inputs. It must:

1. enumerate the requested surface before scanning and report inaccessible or missing coverage;
2. scan exact bytes and safely extracted bounded archive/media content without invoking repository code;
3. never print a pattern, matching value, matching line, surrounding context, secret, or unsafe path;
4. fail closed on scanner errors, decoding failures, unsupported files, extraction limits, or incomplete history;
5. return only the safe report fields defined below.

The scanner must not copy the private corpus into a temporary directory under the repository or retain it in a build artifact. If temporary external storage is unavoidable, it requires restrictive permissions and verified cleanup, while the report records only that protected input was supplied.

### Non-echoing report contract

A public or retained review report is limited to:

- scan date and exact repository revision or protected ref;
- scanner name/version and an opaque private-corpus version identifier;
- every requested surface and its `passed`, `failed`, `not run`, or `not applicable` state;
- counts by safe category and surface;
- a repository-relative path only when the path itself reveals no private value; otherwise an opaque local review reference;
- artifact type, filename only when safe, digest, and installed-manifest digest;
- narrow exception identifier, safe rationale, owner, review date, and expiry or revalidation event;
- reviewer identity or approved review role and final decision.

Reports must never print or persist matched values, private patterns, raw matching context, credentials, unsafe paths, full child output, or a copy of the private corpus. Exception records cannot allow a raw value or pattern into Git. Detailed investigation remains in a protected local channel and does not become public release evidence.

### Status and publication rules

- Every unresolved provenance match blocks publication. Missing required surface coverage, a missing private corpus, a scanner failure, an unreviewed exception, or a required surface marked `not run` also blocks publication.
- A future artifact that does not yet exist is `not applicable`, not passed. Once a release candidate creates that artifact, it becomes required and must be scanned.
- Current Phase 0 development can continue while the private-corpus scan remains `not run`; it cannot claim that the private-information gate passed. The missing external corpus is a publication blocker, not a Phase 1 implementation dependency, unless a later security decision explicitly changes that boundary. Phase 9 owns complete artifact enforcement.
- A suspected real credential is revoked or rotated before content cleanup or history rewriting. Cleanup cannot assume existing clones, caches, logs, or provider copies are recalled.
- Evidence is preserved as safe metadata even when publication is blocked. A failed or unresolved review cannot be deleted, relabeled as clean, or replaced by a narrower successful scan.
- Publication also remains subject to the separate identity and qualified legal-review gate; passing this firewall would not grant publication authority by itself.

Secret scanning is defense in depth, not a complete provenance review or a substitute for the external private corpus. Secret detectors miss non-credential private material and unsupported formats. Likewise, language heuristics support review but do not prove English-only semantics.

### Maintainer review procedure

1. Freeze the candidate revision and enumerate every required surface, including all Git refs and any gem, archive, media, documentation, release-note, CI, or installed-artifact output.
2. Record absent future surfaces as `not applicable`; record missing access, corpus, scanner, or artifact evidence as `not run`.
3. Run secret scanning, language checks, and the external private-pattern scan independently. None substitutes for another.
4. Review every safe category/count result and any protected local match without moving values into the repository or report.
5. Revoke or rotate any real credential first; then resolve content, history, cache, artifact, and provider copies as far as possible.
6. Rebuild changed artifacts once, rescan every affected surface, and retain the new digest chain without erasing prior blocked evidence.
7. Authorize publication only when every required surface is `passed`, every exception is narrow and current, zero matches remain unresolved, and all separate legal, dependency, security, and release gates are satisfied.

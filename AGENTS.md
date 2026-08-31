# AGENTS.md

## Working here

- Read the relevant code, configuration, Xcode project settings, and sibling implementations before editing. Existing code and external references are evidence; understand the invariant and ownership boundary before choosing a solution.
- Target current supported behaviour. Prefer the simplest design that reduces state and machinery, and bring the affected path into conformance when existing code disagrees with this baseline.
- Preserve unrelated work. Keep changes focused, remove artifacts orphaned by the change, and keep generated outputs with their source change.
- Verify framework and platform APIs from the SDK and deployment targets used by the Xcode project.
- Keep secrets, credentials, real identities, production data, Keychain contents, and local environment files out of source, fixtures, logs, and commits.

## Baseline

- Write idiomatic, modern code for the versions and deployment targets pinned by this repository.
- Keep operations idempotent. Re-running imports, scans, refreshes, or mutations with identical input shouldn't accumulate side effects.
- Stay DRY and minimal without premature abstraction. Three similar call sites are fine; add a helper, protocol, options type, or reusable view when real callers need the variance it provides.
- Comments explain non-obvious constraints, invariants, and external requirements. Names and structure carry the ordinary narrative.
- Do not add file banners, author or date headers, or comment-based change logs. Git owns provenance and history.
- Write prose from the repository's point of view. Use `we` and `our` for the organisation, and `the app`, `the service`, `the command`, or direct wording for this repository. Omit organisation and product names when context already identifies them; keep names that are identifiers or distinguish an external system.
- Keep tracked documentation durable and present-tense. READMEs use a terse introduction and the relevant established emoji-led sections; omit migration history, temporary setup state, and inventories of absent features.
- Keep one-time local and external-service setup notes out of tracked files. If asked to preserve them locally, leave them untracked without adding ignore or exclude rules.
- Tests protect behaviour and contracts at the lowest useful boundary. Use synthetic service data and focused fakes for networking, Keychain, scanning, and persistence boundaries.

## Repository tooling

- Mise owns command-line tools and repository tasks. Run `mise tasks` and read `.mise/config.toml` before choosing task names or invoking pinned tools directly.
- Lefthook extends the shared organisation configuration. Read `.lefthook.toml` and use `lefthook dump` when merged hook behaviour matters; local hooks contain only repository-specific additions.
- SwiftFormat owns Swift formatting. The Xcode project and shared scheme own targets, build settings, deployment targets, signing inputs, and build selection.
- Use the runner's default Xcode selection. Select another toolchain only when the repository has a verified version requirement.
- Run focused checks while working, then the relevant format, lint, build, workflow, signing, packaging, and notarization checks before calling the work complete.

## Swift and Apple platforms

- Use Swift 6 language mode and strict concurrency. Prefer `async`/`await`, task groups, actors, and `AsyncSequence`; isolate UI state to the main actor, keep cross-actor values `Sendable`, propagate cancellation, and avoid detached tasks unless inherited isolation is unsuitable.
- Build interfaces with SwiftUI and one clear owner for mutable state. Prefer Observation for new model state, derive view state, and keep user actions in handlers.
- Use AppKit or UIKit only through narrow, documented bridges when current SwiftUI APIs do not provide the required platform behaviour. Keep framework types and lifecycle concerns at that boundary.
- Model expected states directly. Surface actionable failures at the UI boundary and preserve underlying errors for logs and diagnostics.
- Keep service clients responsible for transport and wire models. Put workflow decisions in the state or feature boundary that owns them.
- Build the affected destination. Build both iOS Simulator and macOS when shared code, project settings, or release inputs change.
- Interface copy carries useful meaning. Omit manufactured metadata, and give independent facts separate semantic structure instead of joining them with decorative glyphs. Preserve intentional Unicode content rather than replacing punctuation mechanically.

## Git and completion

- Use focused Conventional Commits; Release Please derives versions from them where configured.
- Commit, push, publish, deploy, contact live systems, or perform destructive operations only when explicitly requested.
- Report the checks run, behaviour changed, signing or packaging evidence collected, and any verification that couldn't be completed.

## Repository contract

- The app supports iOS and macOS from one Xcode project. Keep shared workflows platform-neutral and platform-specific behaviour at the edge.
- Repair, restock, sale preparation, deduplication, and device administration remain distinct user workflows over shared service clients.
- Restock and Sale share device capture and processing primitives. They apply a user-selected Snipe-IT status rather than defining status semantics in the app.
- The Xcode project and release workflows own build, signing, version, and distribution contracts.

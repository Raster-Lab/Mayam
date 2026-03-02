# Copilot Instructions for Mayam

## Project Overview

Mayam is a departmental-level PACS (Picture Archiving and Communication System) built entirely in **Swift 6.2** with strict concurrency. It targets **macOS (Apple Silicon)** and **Linux (x86_64, aarch64)** and follows the **DICOM Standard 2026a** (XML edition).

The codebase is organised as a Swift Package Manager workspace with the following module targets:

| Target | Purpose |
|---|---|
| `MayamServer` | Main server entry point |
| `MayamCore` | Core PACS engine, storage, DICOM services, database |
| `MayamWeb` | DICOMweb and Admin REST API |
| `MayamAdmin` | Web console static assets |
| `MayamCLI` | Command-line administration tools |

Key dependencies include [DICOMKit](https://github.com/Raster-Lab/DICOMKit), [J2KSwift](https://github.com/Raster-Lab/J2KSwift), [JLSwift](https://github.com/Raster-Lab/JLSwift), [JXLSwift](https://github.com/Raster-Lab/JXLSwift), [OpenJP3D](https://github.com/Raster-Lab/OpenJP3D), and [HL7kit](https://github.com/Raster-Lab/HL7kit).

---

## Best Practices

### Swift Language & Concurrency

- Use **Swift 6.2** language features and strict concurrency throughout.
- Prefer **actors** for mutable shared state; avoid manual locks or `DispatchQueue` synchronisation.
- Use **structured concurrency** (`async`/`await`, `TaskGroup`, `AsyncStream`) instead of callbacks or completion handlers.
- Mark all value types that cross concurrency boundaries as `Sendable`.
- Enable and respect **strict concurrency checking** (`-strict-concurrency=complete`); resolve all warnings as errors.

### Code Style & Conventions

- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Use `///` documentation comments on every `public` symbol; include `- Parameters:`, `- Returns:`, and `- Throws:` sections where appropriate.
- Organise source files with `// MARK: -` sections (e.g. `// MARK: - Stored Properties`, `// MARK: - Initialiser`, `// MARK: - Public Methods`).
- Include the SPDX licence header at the top of every source file: `// SPDX-License-Identifier: (see LICENSE)`.
- Prefer `let` over `var`; use `var` only when mutation is required.
- Use `guard` for early exits and precondition validation.
- Prefer `Codable` conformance over manual serialisation.

### DICOM & Healthcare Standards

- Follow the **DICOM 2026a** standard for tag definitions, value representations, and service class semantics.
- Use DICOM tag notation `(GGGG,EEEE)` in documentation comments when referencing attributes (e.g. `/// DICOM Patient ID (0010,0020)`).
- Validate DICOM UIDs against the UID format rules (max 64 characters, dot-separated numeric components).
- Respect **Delete Protect** and **Privacy Flag** semantics on Patient, Accession, and Study entities; never bypass these flags without explicit authorisation.
- Audit all changes to protection flags in the `protection_flag_audit` table.

### HL7 & FHIR Interoperability

- Use **[HL7kit](https://github.com/Raster-Lab/HL7kit)** for **all** HL7 and FHIR functionality — do not re-implement parsing, serialisation, validation, networking, or resource models that HL7kit already provides.
- Use HL7kit's **`HL7v2Kit`** module for HL7 v2.x messaging (MLLP transport, ADT/ORM/ORU/ACK message types, data types, validation, and encoding).
- Use HL7kit's **`HL7v3Kit`** module for any HL7 v3.x / CDA requirements.
- Use HL7kit's **`FHIRkit`** module for FHIR R4 resources, REST client operations, search, validation, SMART on FHIR authentication, terminology services, and subscriptions.
- If a required FHIR resource or HL7 capability is **not yet available** in HL7kit, contribute the implementation to [HL7kit](https://github.com/Raster-Lab/HL7kit) first rather than building it directly in Mayam.

### Error Handling

- Define domain-specific error types conforming to `Error` and `Sendable`.
- Prefer `throws` over optional returns for operations that can fail.
- Include contextual information (entity type, ID, operation) in error descriptions.
- Log errors with appropriate severity levels using the project logging subsystem (`os_log` on macOS, `swift-log` on Linux).

### Database

- Use **PostgreSQL 18.3** as the primary metadata database; support **SQLite** as a fallback for lightweight deployments.
- Place database migrations in `Sources/MayamCore/Database/Migrations/` as sequentially numbered SQL files (e.g. `002_add_series_table.sql`).
- Use parameterised queries exclusively; never interpolate user input into SQL strings.
- Wrap related schema changes in a transaction (`BEGIN` / `COMMIT`).

### Security

- Never commit secrets, credentials, or API keys into source code.
- Use TLS 1.3 for all network communication (DICOM TLS, HTTPS).
- Validate and sanitise all external input (DICOM data, HTTP requests, HL7 messages).
- Follow OWASP secure coding guidelines for the web API layer.

### Performance

- Use **Swift NIO** for non-blocking, asynchronous I/O.
- Prefer zero-copy buffer handling where possible.
- Leverage Apple Silicon optimisations (NEON SIMD, Accelerate framework) on macOS; use portable SIMD paths on Linux.

---

## Test Code Coverage

- **Maintain a minimum of 95% test code coverage** across the entire codebase.
- Every new feature, bug fix, or refactor **must** include corresponding unit tests or integration tests that preserve or increase overall coverage.
- Write tests in the matching `Tests/` target (e.g. `Tests/MayamCoreTests/` for `MayamCore` source changes).
- Use **XCTest** as the testing framework.
- Test both the success (happy) path and failure/edge-case paths for every public API.
- Include negative tests: invalid input, boundary conditions, permission denials (e.g. Delete Protect preventing deletion).
- Use descriptive test method names following the pattern `test_<unit>_<scenario>_<expectedBehaviour>` (e.g. `test_patient_deleteProtectEnabled_preventsRemoval`).
- Mock external dependencies (database, network, file system) in unit tests to ensure isolation and speed.
- Run the full test suite with `swift test --enable-code-coverage` and verify coverage before merging.
- Do not reduce existing coverage with any change; if legacy code is modified, add tests to bring it to the 95% threshold.

---

## Documentation Updates

- **Every code change must include corresponding documentation updates.** No pull request should be merged without documentation reflecting the change.
- Update **inline documentation** (`///` doc comments) whenever a public API signature, behaviour, or semantics change.
- Update **README.md** when adding, removing, or changing user-facing features, configuration options, build steps, or project structure.
- Update **milestones.md** when completing or revising milestone deliverables.
- Update or create **database migration comments** when schema changes are introduced.
- When adding a new module, endpoint, or service, ensure it is reflected in the Project Structure section of `README.md`.
- Keep all documentation concise, accurate, and in sync with the code at all times.
- Use proper Markdown formatting and maintain consistent style with existing documentation.

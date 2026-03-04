<!-- SPDX-License-Identifier: (see LICENSE) -->

# Releasing Mayam

This document describes the release branching strategy and the steps required to
publish a new Mayam release.

---

## Branching Strategy

Mayam follows a **release-branch** model:

| Branch | Purpose |
|---|---|
| `main` | Active development. All feature work merges here first. |
| `release/vX.Y.Z` | Stabilisation branch for a specific release. Only bug-fixes and documentation updates are merged here after the branch is cut. |

### Lifecycle

```
main ──●──●──●──●──●──●──●──●──●──
                \                 \
                 release/v1.0.0    release/v1.1.0
                 ●──●──● → tag v1.0.0   ...
```

1. **Cut the release branch** from `main` when the release scope is feature-complete.
2. **Stabilise** on the release branch — only bug-fixes and documentation updates.
3. **Tag** the release commit (e.g. `v1.0.0`) when the branch is ready.
4. The tag triggers the **Release** workflow, which builds binaries, publishes
   Docker images, and creates the GitHub Release.
5. **Merge back** any stabilisation fixes from the release branch into `main`.

---

## Prerequisites

- Push access to the repository.
- All milestones for the target release are marked **✅ Complete** in
  `milestones.md`.
- `RELEASE_NOTES.md` is up to date for the target version.
- The full test suite passes on both macOS and Linux (`swift test`).

---

## Step-by-Step Release Process

### 1. Create the Release Branch

Use the **Create Release Branch** workflow from the Actions tab:

1. Navigate to **Actions → Create Release Branch**.
2. Click **Run workflow** (the branch dropdown does not matter — the workflow
   always creates from `main`).
3. Enter the version (e.g. `1.0.0`) and confirm.

The workflow validates the version format, checks that the branch does not
already exist, and creates `release/v1.0.0` from `main`.

Alternatively, create the branch manually:

```bash
git checkout main
git pull origin main
git checkout -b release/v1.0.0
git push origin release/v1.0.0
```

The CI workflow runs automatically on `release/**` branches.

### 2. Stabilise

Apply any last-minute fixes directly to the release branch via pull requests.
Keep changes minimal — only bug-fixes and documentation corrections.

### 3. Update Version References

Verify that the following files reference the correct version:

| File | Field |
|---|---|
| `RELEASE_NOTES.md` | Title, tag, and release date |
| `packaging/homebrew/mayam.rb` | `url` and `sha256` |
| `Dockerfile` | Base image tags (if pinned) |
| `docker-compose.yml` | Image tags (if pinned) |
| `docs/DEPLOYMENT_GUIDE.md` | Version references in commands |

### 4. Tag the Release

```bash
git checkout release/v1.0.0
git tag -a v1.0.0 -m "Mayam v1.0.0"
git push origin v1.0.0
```

Pushing the tag triggers the **Release** workflow
(`.github/workflows/release.yml`), which:

1. Runs the full test suite on Linux and macOS.
2. Builds release binaries for Linux (x86_64, aarch64) and macOS (arm64).
3. Builds and pushes multi-architecture Docker images to
   `ghcr.io/raster-lab/mayam`.
4. Creates a **GitHub Release** with the release notes and binary assets.

### 5. Verify the Release

- Confirm the [GitHub Release](https://github.com/Raster-Lab/Mayam/releases)
  page shows the correct version, release notes, and downloadable assets.
- Pull and test the Docker image:

  ```bash
  docker pull ghcr.io/raster-lab/mayam:1.0.0
  docker run --rm ghcr.io/raster-lab/mayam:1.0.0 --version
  ```

### 6. Merge Back to Main

```bash
git checkout main
git merge release/v1.0.0
git push origin main
```

Resolve any conflicts, ensuring `main` includes all stabilisation fixes.

### 7. Post-Release

- Update `milestones.md` if applicable.
- Announce the release through the appropriate channels.

---

## Automated Workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| **CI** (`.github/workflows/ci.yml`) | Push/PR to `main` or `release/**` | Build, test, and lint |
| **Create Release Branch** (`.github/workflows/create-release-branch.yml`) | Manual (`workflow_dispatch`) | Create a `release/vX.Y.Z` branch from `main` |
| **Release** (`.github/workflows/release.yml`) | Tag push `v*.*.*` | Build release binaries, publish Docker images, create GitHub Release |
| **CodeQL** (`.github/workflows/codeql.yml`) | Push/PR to `main` | Security scanning |

---

## Pre-release Versions

For release candidates or beta releases, use a pre-release suffix in the tag:

```bash
git tag -a v1.1.0-rc.1 -m "Mayam v1.1.0 Release Candidate 1"
git push origin v1.1.0-rc.1
```

The release workflow automatically marks tags containing a hyphen (`-`) as
**pre-release** on the GitHub Releases page.

---

## Hotfix Process

For critical fixes to an already-released version:

1. Check out the existing release branch (e.g. `release/v1.0.0`).
2. Apply the fix via a pull request to the release branch.
3. Tag a patch release (e.g. `v1.0.1`).
4. Merge the fix back to `main`.

---

*See also: [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) ·
[Administrator Guide](docs/ADMINISTRATOR_GUIDE.md)*

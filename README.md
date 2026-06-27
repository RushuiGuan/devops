# devops

Reusable GitHub Actions workflows shared across `RushuiGuan` repositories.

## Workflows

| Workflow | Trigger (in caller) | Publishes |
|---|---|---|
| `prerelease.yml` | push to `rc` | `{Version}-rc.{commit count}` → GitHub Packages |
| `github-release.yml` | `vX.Y.Z` tag on `production` | `{Version}` → GitHub Packages |
| `nuget-release.yml` | `vX.Y.Z` tag on `production` | `{Version}` → nuget.org (public packages only) |

All three read the package list from the **caller's** `.projects` file
(the `# packages` section) and the version from the caller's
`Directory.Build.props` `<Version>`. The caller's repo is what gets checked
out, so these files come from the calling repository, not from `devops`.

### Inputs

| Input | Default | Applies to |
|---|---|---|
| `dotnet-version` | `10.0.x` | all three |

### Secrets

| Secret | Required by | Notes |
|---|---|---|
| `GITHUB_TOKEN` | all three | Built-in; provided automatically via `secrets: inherit`. |
| `NUGET_API_KEY` | `nuget-release.yml` | Must exist in the **calling** repo. |

## Using it from another repo

Add a single workflow to the calling repo, e.g. `.github/workflows/nuget.yml`.
The caller defines the triggers and gates each job by ref; the reusable
workflows do the work.

```yaml
name: nuget

on:
  push:
    branches:
      - rc
    tags:
      - 'v*'

permissions:
  contents: read
  packages: write   # a reusable workflow's token cannot exceed the caller's

jobs:
  prerelease:
    if: github.ref == 'refs/heads/rc'
    uses: RushuiGuan/devops/.github/workflows/prerelease.yml@v1
    secrets: inherit

  github-release:
    if: startsWith(github.ref, 'refs/tags/v')
    uses: RushuiGuan/devops/.github/workflows/github-release.yml@v1
    secrets: inherit

  # Public packages only. Omit this job in private repos so nothing
  # can leak to the public feed.
  nuget-release:
    if: startsWith(github.ref, 'refs/tags/v')
    uses: RushuiGuan/devops/.github/workflows/nuget-release.yml@v1
    secrets: inherit
```

### Notes

- **Pin a ref.** Reference `@v1` (tag this repo) or `@main`. Pinning controls
  when callers pick up changes.
- **Private callers need access.** If `devops` is private, enable
  Settings → Actions → General → Access → "Accessible from repositories owned
  by RushuiGuan". Making `devops` public avoids this (it holds no secrets).
- **Branch model the callers follow:** `main` (work, publishes nothing) →
  `rc` (prereleases) → `production` (PR-locked; tag `vX.Y.Z` here for stable).
- **Per-package nuget.org opt-in** is expressed by composition: a repo that
  should publish to nuget.org adds the `nuget-release` job; a private repo
  simply omits it.
- Symbol packages (`.snupkg`) are not pushed to GitHub Packages (unsupported)
  but are pushed to nuget.org alongside their `.nupkg`.

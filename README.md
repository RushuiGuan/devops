# devops

Reusable GitHub Actions workflows shared across `RushuiGuan` repositories.

## Workflows

| Workflow | Trigger (in caller) | Publishes |
|---|---|---|
| `nuget-prerelease.yml` | push to `rc` | `{Version}-rc.{commit count}` → GitHub Packages |
| `nuget-release-github.yml` | `vX.Y.Z` tag on `production` | `{Version}` → GitHub Packages |
| `nuget-release-nugetorg.yml` | `vX.Y.Z` tag on `production` | `{Version}` → nuget.org (public packages only) |

All three read the package list from the **caller's** `.projects` file
(the `# packages` section) and the version from the caller's
`Directory.Build.props` `<Version>`. The caller's repo is what gets checked
out, so these files come from the calling repository, not from `devops`.

### Inputs

| Input | Default | Applies to |
|---|---|---|
| `dotnet-version` | `10.0.x` | all three |
| `nuget-user` | *(required)* | `nuget-release-nugetorg.yml` — nuget.org profile name owning the Trusted Publishing policy |

### Secrets

No secrets needed. `GITHUB_TOKEN` is provided automatically to reusable
workflows, and nuget.org publishing uses **Trusted Publishing (OIDC)** rather
than a `NUGET_API_KEY` — the caller just grants `id-token: write`.

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
  id-token: write   # required for nuget-release-nugetorg (Trusted Publishing OIDC)

jobs:
  prerelease:
    if: github.ref == 'refs/heads/rc'
    uses: RushuiGuan/devops/.github/workflows/nuget-prerelease.yml@v1
    secrets: inherit

  github-release:
    if: startsWith(github.ref, 'refs/tags/v')
    uses: RushuiGuan/devops/.github/workflows/nuget-release-github.yml@v1
    secrets: inherit

  # Public packages only. Omit this job in private repos so nothing
  # can leak to the public feed.
  nuget-release:
    if: startsWith(github.ref, 'refs/tags/v')
    uses: RushuiGuan/devops/.github/workflows/nuget-release-nugetorg.yml@v1
    with:
      nuget-user: RushuiGuan   # your nuget.org profile name
```

> Use `nuget-release-github` **or** `nuget-release-nugetorg` (or both) per repo —
> public packages typically use nugetorg only. A private repo should use neither
> a public target nor `id-token: write`.

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
- **nuget.org Trusted Publishing setup.** nuget.org matches the OIDC
  `job_workflow_ref` claim, which — for a reusable workflow — points at THIS
  repo's workflow, not the caller's. So create **one** policy on nuget.org
  (your username → Trusted Publishing) and it covers every caller:
  - **Repository Owner:** `RushuiGuan`
  - **Repository:** `devops`
  - **Workflow File:** `nuget-release-nugetorg.yml`
  - **Environment:** *(leave empty)*

  The caller must grant `id-token: write` (above) or the `job_workflow_ref`
  claim is omitted and the token exchange fails with `401: No matching trust
  policy`.

# devops

Shared GitHub Actions building blocks for `RushuiGuan` repositories.

## What's here

**Reusable workflows** (`.github/workflows/`) — publish to **GitHub Packages** using the built-in `GITHUB_TOKEN`:

| Workflow | Trigger (in caller) | Publishes |
|---|---|---|
| `nuget-prerelease.yml` | push to `rc` | `{Version}-rc.{commit count}` → GitHub Packages |
| `nuget-release-github.yml` | `vX.Y.Z` tag on `production` | `{Version}` → GitHub Packages |

**Composite action** (`.github/actions/`) — publishes to **nuget.org** via Trusted Publishing:

| Action | Used on | Publishes |
|---|---|---|
| `nuget-release-nugetorg` | `vX.Y.Z` tag on `production` | `{Version}` → nuget.org, then a GitHub Release from the tag (public packages only) |

All three read the package list from the **caller's** `.projects` file (the
`# packages` section) and the version from the caller's `Directory.Build.props`
`<Version>`. The caller's repo is what gets checked out, so these come from the
calling repository, not from `devops`.

### Why nuget.org is a composite *action*, not a reusable *workflow*

nuget.org Trusted Publishing matches the OIDC **`job_workflow_ref`** claim against
your policy, and that claim must be the **caller's** workflow. A reusable workflow
makes `job_workflow_ref` point at `devops` (never matches a caller policy), and
the alternative of minting the key in the caller and passing it to a reusable
workflow fails because GitHub **redacts masked secrets written to job outputs**.
A composite action runs `NuGet/login` + push as steps **inside the caller's job**,
so `job_workflow_ref` stays the caller's workflow and the masked key never crosses
a job boundary.

### Inputs

| Input | Default | Applies to |
|---|---|---|
| `dotnet-version` | `10.0.x` | all |
| `nuget-user` | *(required)* | `nuget-release-nugetorg` — nuget.org profile name owning the Trusted Publishing policy |

### Secrets

None. `GITHUB_TOKEN` is provided automatically; nuget.org uses Trusted Publishing
(OIDC), so there's no `NUGET_API_KEY`.

## Using it from another repo

Add `.github/workflows/nuget.yml` to the calling repo:

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
  packages: write

jobs:
  prerelease:
    if: github.ref == 'refs/heads/rc'
    uses: RushuiGuan/devops/.github/workflows/nuget-prerelease.yml@v1
    secrets: inherit

  # Stable to GitHub Packages (private packages, or as a mirror). Reusable workflow.
  github-release:
    if: startsWith(github.ref, 'refs/tags/v')
    uses: RushuiGuan/devops/.github/workflows/nuget-release-github.yml@v1
    secrets: inherit

  # Stable to nuget.org (public packages only). Composite action - runs in this job.
  nuget-release:
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    permissions:
      contents: write          # create the GitHub Release
      packages: read
      id-token: write          # required for Trusted Publishing OIDC
    steps:
      - uses: RushuiGuan/devops/.github/actions/nuget-release-nugetorg@v1
        with:
          nuget-user: Rushui    # your nuget.org profile name
```

Use whichever release path(s) a repo needs — `github-release`, `nuget-release`,
or both. A private repo should use neither nuget.org nor `id-token: write`.

### Notes

- **Pin a ref.** Reference `@v1` (a moving major tag on this repo) or `@main`.
- **`devops` must be public** for public callers — GitHub forbids public repos
  from consuming a private repo's actions/reusable workflows. It holds no secrets.
- **Branch model the callers follow:** `main` (work, publishes nothing) →
  `rc` (prereleases) → `production` (PR-locked; tag `vX.Y.Z` here for stable).
- Symbol packages (`.snupkg`) are not pushed to GitHub Packages (unsupported)
  but are pushed to nuget.org alongside their `.nupkg`.

### nuget.org Trusted Publishing setup (per public repo)

Because the composite action runs in the caller, the OIDC `job_workflow_ref` is
the **caller's** workflow — so the policy is **per calling repo**, not on `devops`.
On nuget.org → your username → Trusted Publishing, create a policy for each public
repo:

- **Repository Owner:** `RushuiGuan`
- **Repository:** the calling repo (e.g. `exceptions`)
- **Workflow File:** the calling workflow (e.g. `nuget.yml`)
- **Environment:** *(leave empty)*
- **User (`nuget-user`):** the profile name that **created** the policy

A new policy starts in a 7-day pending window; the first successful publish makes
it permanent.

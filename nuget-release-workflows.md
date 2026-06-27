# Nuget Package Release Process

Packages are published to **GitHub Packages** by `.github/workflows/nuget.yml`.
The workflow is fully parameterized — it reads the package list from `.projects`
and the version from `Directory.Build.props` — so the same file works unchanged
across repos.

## Branch model

```
main       ──work──work──work        work branch; publishes NOTHING
                  │  bump <Version> to the target you're heading toward
                  ▼
rc         ──────o─o─o                every push -> {Version}-rc.{commit count}  (prerelease)
                    │ candidate passes QA; open PR
                    ▼
production ─────────o                 PR-only; tag vX.Y.Z here -> {Version}  (stable)
```

| Branch | Role | Publishes |
|---|---|---|
| `main` | Work branch / source of truth for `<Version>` | Nothing |
| `rc` | Integration / release-candidate channel | `{Version}-rc.{commit count}` on every push |
| `production` | Released code; PR-only, locked | Stable `{Version}` when a `vX.Y.Z` tag is pushed |

The version always comes from `Directory.Build.props` `<Version>`. **It names the
release you are working *toward*, not the last one shipped.** Bump it forward
right after each stable release.

## Channels

### Prerelease — push to `rc`

Every push to `rc` publishes `{Version}-rc.{commit count}` (e.g. `1.0.0-rc.47`).
The commit count (`git rev-list --count HEAD`) is monotonic, so candidates always
sort forward. Prereleases go to GitHub Packages only — never to nuget.org.

**Guard:** if a tag `v{Version}` already exists, the job fails. You cannot publish
`1.0.0-rc.N` after `1.0.0` has shipped (those candidates would sort *below* the
stable release). The check is exact-match: an unrelated higher release such as
`v1.0.1` does not block `1.0.0-rc.N`.

### Stable — push a `vX.Y.Z` tag on `production`

A `v*` tag publishes the clean `{Version}` to GitHub Packages, but only after two
guards pass:

1. **Version match** — the tag (minus the `v`) must equal `Directory.Build.props`
   `<Version>`. `v1.0.0` requires `<Version>` to be `1.0.0`.
2. **On production** — the tagged commit must be reachable from `origin/production`.
   A `v*` tag created anywhere else (on `main`, `rc`, a feature branch) fails and
   publishes nothing.

You can't stop someone from *creating* a `v*` tag elsewhere, but a misplaced tag
is a no-op — only a tag on `production` whose version matches the repo releases.

## Cutting a release

1. On `main`, set `<Version>` in `Directory.Build.props` to the target (e.g. `1.0.0`).
2. Promote work to `rc`; each push publishes `1.0.0-rc.N` candidates for testing.
3. When a candidate is blessed, open a PR from `rc` (or the blessed commit) into
   `production` and merge it.
4. Tag the `production` commit:
   ```
   git checkout production && git pull
   git tag v1.0.0
   git push origin v1.0.0
   ```
   The workflow validates both guards and publishes stable `1.0.0`.
5. Bump `<Version>` to the next target (e.g. `1.1.0`) on `main` and `rc` so the
   next rc cycle starts above the release just shipped.

## Adding a package

Add the project's folder name under the `# packages` section of `.projects`:

```
# packages
Albatross.Exceptions
Albatross.Something      <- new package
```

No workflow change is needed. Each entry must be a folder containing a like-named
`.csproj` (`Albatross.Something/Albatross.Something.csproj`) that is packable
(README, icon, and license includes). Other sections (`# apps`, `# services`, …)
are ignored.

## One-time GitHub setup

These live in repo settings, not in the workflow:

- **Branches:** create `rc` and `production`. The workflow only fires once it
  exists on the branch/tag being pushed, so let it propagate `main -> rc -> production`.
- **`production` ruleset** (Settings → Rules → Rulesets, target `production`):
  require a pull request, block force-push and deletion. This is the PR-only lock.
- **Tag ruleset (optional)** (target Tag, pattern `v*`): restrict tag creation to
  yourself / a release team so stray `v*` tags can't be made. Note this limits
  *who* tags, not *where* — the on-production binding is enforced by guard 2 above.

## Authentication

- **Publishing** uses the built-in `GITHUB_TOKEN` (`packages: write`). No PAT,
  no committed `nuget.config`.
- **Consuming** packages from GitHub Packages: the workflow adds the feed as a
  source with `GITHUB_TOKEN` at runtime (the "Configure GitHub Packages source"
  step), so restore resolves dependencies from your feed without a PAT.
  - Public package → any repo's Actions can restore it.
  - Private package, same repo → works automatically.
  - Private package, *different* repo → grant the consuming repo access once:
    Package → Manage Actions access → add the repo.
  - **Local dev** (Visual Studio, etc.) always needs a PAT with `read:packages` —
    the GitHub Packages NuGet feed requires auth even for public packages.

## Notes

- Symbol packages (`.snupkg`) are produced but **not** pushed — GitHub Packages
  doesn't accept them. SourceLink still works for consumers.
- nuget.org publishing is **not** wired up yet. When added, it will be a prod-only,
  opt-in target (public packages only); prereleases stay on GitHub Packages.

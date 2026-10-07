---
include_toc: true
gitea: none
---

# Gitea Windows CI

`.github/workflows/ci.yml` on this branch is the Gitea Actions workflow
for a Windows runner. Placeholders stay until Gary answers the questions
at the end.

<!-- paperboy-wiki-source: docs/GITEA_WINDOWS_CI.md -->

## Intent

Workflows stay in `.github/workflows/`. Jobs run on Windows. Lint needs
no database. Tests stay off until a SQL host is named. The tag job waits
for lint and test. Passwords stay in Gitea secrets.

## What the workflow does now

Each job sets `runs-on: ${{ vars.CI_RUNNER_LABEL || 'windows' }}`.
Every `run:` step sets `shell: bash` (Git Bash). A `uses:` step does
not set a shell.

| Job | Runs | Gate |
| --- | ---- | ---- |
| `lint` | RuboCop, Brakeman, bundle-audit. No database or secrets. | Always. |
| `test` | `rails test`, then system tests when enabled. | `needs: lint`. Off until `CI_SQL_HOST` is set. |
| `tag-master-commit` | `bash bin/tag-master-commit`. | `needs: [lint, test]`. Push to `master` only. |

Lint and test both check out the tree and run `ruby/setup-ruby`.
System tests run `rails test:system` when `CI_SYSTEM_TESTS` is `true`.
The screenshot upload runs on `failure()` with that same flag. The tag
job checks out with `fetch-depth: 0`.

The workflow has no MSSQL service container, no sqlcmd health check,
no inline SA password, no apt Chrome install, and no
`${{ github.workspace }}`.

## Gitea configuration

Repository variables. The workflow default applies when the variable is
empty or unset.

| Variable | Default | Effect |
| -------- | ------- | ------ |
| `CI_RUNNER_LABEL` | `windows` | Runner label. |
| `CI_SQL_HOST` | empty | Empty skips the test job. |
| `CI_SQL_PORT` | `1433` | SQL Server port (`GSABSS_PORT`). |
| `CI_SQL_DATABASE` | `Paperboy_Test` | Test database name. |
| `CI_SYSTEM_TESTS` | unset | `true` runs system tests. |

`CI_SQL_DATABASE` sets `GSABSS_DATABASE` and `PAPERBOY_TEST_DATABASE`.

Secrets. They are not written in YAML. Point them at a CI login for
`Paperboy_Test` only, never Dev, Stage, or Prod data. The test login
needs to create and drop databases.

| Secret | Maps to |
| ------ | ------- |
| `CI_SQL_USERNAME` | `GSABSS_USERNAME` |
| `CI_SQL_PASSWORD` | `GSABSS_PASSWORD` |

## Runner requirements

Git for Windows, with its `bash.exe` ahead of
`C:\Windows\System32\bash.exe` (WSL) on `PATH`. `shell: bash` must be
that Git Bash.

Ruby comes from `ruby/setup-ruby`, or from RubyInstaller+DevKit when
that action cannot be fetched.
`bundler-cache: true` needs the act_runner cache server enabled;
without it every run installs gems from scratch.

`tiny_tds` is `force_ruby_platform: true`, so the runner needs FreeTDS
when Bundler compiles the gem.

Chrome is required only when `CI_SYSTEM_TESTS` is `true`. The workflow
does not install it.

## Line endings

Root `.gitattributes`:

| Pattern | Ending |
| ------- | ------ |
| `*.sh`, `bin/*`, `*.yml`, `*.yaml` | LF |
| `*.ps1`, `*.cmd`, `*.bat` | CRLF |

Git Bash breaks on CRLF shell scripts. `script/python/aim/.gitattributes`
already sets `*.bat` to CRLF for cmd.exe on GSA-SCAN02. The root rule
matches that for `*.bat`.

## Tagging

`bin/tag-master-commit` uses `GITEA_SHA`, then `GITHUB_SHA`, then
`HEAD`. It reads `git config user.name` and `user.email` first. When
either value is empty and `GITEA_ACTIONS` or `GITHUB_ACTIONS` is
`true`, the tagger is `Paperboy CI` /
`paperboy-ci@noreply.invalid`. A workstation with no identity still
errors.

The tag job needs lint and test, so a `master` push is not tagged
while the test job is skipped. Pushing the tag needs the job token to
have `contents: write`. The workflow already sets that permission.

## Dependency updates

`.github/dependabot.yml` is removed. Dependabot does not run on Gitea,
so the file was inert. Renovate is a self-hosted option and is not
chosen.

## Known gaps

`Gemfile.lock` `PLATFORMS` has no `x64-mingw-ucrt`. `setup-ruby` and
Bundler on Windows need this follow-up before `bundle install` can
resolve Windows gems:

```bash
bundle lock --add-platform x64-mingw-ucrt
```

`runs-on` with `vars` needs a Gitea that evaluates expressions in
`runs-on`. This host reports version `28.0.0`; confirm on the first
run. If it does not, replace the expression with a literal label.

## Open questions for Gary

1. **Runner label.** Which Windows `act_runner` label is registered?
   Line: `runs-on: ${{ vars.CI_RUNNER_LABEL || 'windows' }}` on each
   job, when the label is not `windows` or when `runs-on` cannot take
   an expression. Otherwise set `CI_RUNNER_LABEL` and leave the line.

2. **Action mirror / `DEFAULT_ACTIONS_URL`.** `uses:` resolves against
   the server setting `[actions] DEFAULT_ACTIONS_URL`.
   Line: none when that setting points at a mirror. Otherwise change
   `uses: actions/checkout@v4` (and `ruby/setup-ruby@v1`,
   `actions/upload-artifact@v4`) to an absolute `uses: https://...` URL.
   Once the mirror is known, pin each `uses:` to a commit SHA; Semgrep
   flags the mutable `@v4` / `@v1` tags.

3. **SQL host and CI login.** Which host, and which login may create
   and drop test databases?
   Line: none. Set `CI_SQL_HOST`, `CI_SQL_USERNAME`, and
   `CI_SQL_PASSWORD`. The gate stays
   `if: ${{ vars.CI_SQL_HOST != '' }}`.

4. **Chrome and system tests.** Run them once Chrome is on the runner?
   Line: none. Set `CI_SYSTEM_TESTS` to `true`. The step gate stays
   `if: ${{ vars.CI_SYSTEM_TESTS == 'true' }}`.

5. **`.github` vs `.gitea` pickup.** Gitea reads `.gitea/workflows`
   first and falls back to `.github/workflows` only when
   `.gitea/workflows` does not exist. This repo has no
   `.gitea/workflows`. Confirm that fallback.
   Line: none while the fallback is the pickup you want. If not, move
   the workflow to `.gitea/workflows/ci.yml`.

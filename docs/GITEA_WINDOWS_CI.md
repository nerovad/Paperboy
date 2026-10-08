# Gitea Windows CI

`.github/workflows/ci.yml` runs on Gitea Actions on the Windows runner
`gsa-gitearunner`. Lint and security checks run on every pull request
and every push to `master`. Tests wait for a SQL host (stage 2).

## Status

Checked 2026-10-07.

- **Stage 1 is done.** The runner is online and the lint job is green.
  Run 172 on `b99e0ae2` (the #86 merge) was the first green `master`
  run.
- **Stage 2 is open.** It covers the SQL host and login, FreeTDS,
  Ruby+DevKit, and Gary's self-hosted `setup-ruby` change. See
  [Open items](#open-items).

## Intent

Workflows stay in `.github/workflows/`. Jobs run on Windows. Lint needs
no database. Tests stay off until a SQL host is named. The tag job waits
for lint and test. Passwords stay in Gitea secrets.

## What the workflow does now

Each job sets `runs-on: ${{ vars.CI_RUNNER_LABEL || 'windows' }}`.
Gitea 28.0.0 evaluates that expression. `CI_RUNNER_LABEL` is unset, so
jobs go to the `windows` label. Every `run:` step sets `shell: bash`
(Git Bash). A `uses:` step does not set a shell.

| Job | Runs | Gate | Today |
| --- | ---- | ---- | ----- |
| `lint` | RuboCop, Brakeman, bundle-audit. No database or secrets. | Always. | Runs, green. |
| `test` | `rails test`, then system tests when enabled. | `needs: lint`. Off until `CI_SQL_HOST` is set. | Skipped. |
| `tag-master-commit` | `bash bin/tag-master-commit`. | `needs: [lint, test]`. Push to `master` only. | Skipped, because `test` is skipped. |

Lint and test both check out the tree and run `ruby/setup-ruby`.
System tests run `rails test:system` when `CI_SYSTEM_TESTS` is `true`.
The screenshot upload runs on `failure()` with that same flag. The tag
job checks out with `fetch-depth: 0`.

The workflow has no MSSQL service container, no sqlcmd health check,
no inline SA password, no apt Chrome install, and no
`${{ github.workspace }}`.

## Runner

Roy Morris owns, built, and maintains the runner VM.

| Item | Value |
| ---- | ----- |
| Host | `gsa-gitearunner`, 10.135.204.97, Windows Server 2022 |
| Runner | `gitea-runner` v4.1.0 (the renamed `act_runner`) |
| Gitea runner id | 4 |
| Registration | Repository level, `BSS/Paperboy` |
| Label | `windows:host`. Gitea lists it as `windows`. |
| Capacity | 1 job at a time |
| Service | NSSM service `gitea-runner` |
| Service account | Local non-admin account `svc-gitea-runner` |
| Runner folder | `C:\gitea-runner`. Each job works in `C:\gitea-runner\work\<id>\hostexecutor`. |
| Tool cache | `C:\hostedtoolcache` |

`setup-ruby` leaves a folder link (junction) behind after a job. A
post-task script and a pre-start script on the service remove it, so the
next job starts clean.

### Installed tools

- Git for Windows 2.56.0.2. Its `bash.exe` is on `PATH` ahead of
  `C:\Windows\System32\bash.exe` (WSL), so `shell: bash` is Git Bash.
  `core.autocrlf` is `false`.
- Node 24.21.0, which runs JavaScript actions such as `actions/checkout`
  and `ruby/setup-ruby`.
- 7-Zip 26.04.
- No Ruby is installed by hand. `ruby/setup-ruby` downloads Ruby 4.0.6
  (from `.ruby-version`) and the MSYS2 build tools into
  `C:\hostedtoolcache\windows\Ruby\4.0.6\x64`, and sets `RI_DEVKIT`. A
  Ruby installed by hand can conflict with that step.

### Network

There is no proxy, and every outbound host the jobs need is reachable:
`github.com` for the actions and the MSYS2 build tools, `rubygems.org`,
and the BSS gem source at `http://gsa-gitea:3000/api/packages/BSS/rubygems/`.
`uses:` actions download from GitHub, so no mirror is needed.

## Gitea configuration

Repository variables. The workflow default applies when the variable is
empty or unset. None are set today.

| Variable | Default | Effect | Today |
| -------- | ------- | ------ | ----- |
| `CI_RUNNER_LABEL` | `windows` | Runner label. | Unset. Default matches the runner. |
| `CI_SQL_HOST` | empty | Empty skips the test job. | Unset. Stage 2. |
| `CI_SQL_PORT` | `1433` | SQL Server port (`GSABSS_PORT`). | Unset. |
| `CI_SQL_DATABASE` | `Paperboy_CI` | Test database name. Must end in `_CI`. | Unset. |
| `CI_SYSTEM_TESTS` | unset | `true` runs system tests. | Unset. |

`CI_SQL_DATABASE` sets `GSABSS_DATABASE` and `PAPERBOY_TEST_DATABASE`.

Secrets. They are not written in YAML. Point them at a CI login whose only
rights are on the CI database, never Dev, Stage, or Prod data. The login
does not create or drop databases. Neither secret is set yet (stage 2).

| Secret | Maps to |
| ------ | ------- |
| `CI_SQL_USERNAME` | `GSABSS_USERNAME` |
| `CI_SQL_PASSWORD` | `GSABSS_PASSWORD` |

### Test database (stage 2)

The `test` job uses one pre-made database whose name ends in `_CI`
(default `Paperboy_CI`). It never creates or drops a database.

- `bundle exec rails ci:reset_database` runs first. It drops every object
  inside that database (foreign keys, views, procedures, functions,
  tables, then sequences, synonyms, types, and user schemas such as
  `aim`), then loads `db/schema.rb`. It refuses a database whose
  configured name, or whose name as SQL Server reports it, does not end
  in `_CI`.
- `PARALLEL_WORKERS=1` runs the suite in one process, so `test_helper.rb`
  creates no per-worker databases. A parallel run against a `_CI`
  database is refused.
- Against a `_CI` database, `test_helper.rb` turns off Rails' test-schema
  maintenance, which would otherwise purge by dropping and re-creating the
  database.
- `CI_SQL_HOST` plus `CI_SQL_PORT` is all `tiny_tds` needs; no instance
  name. The workflow does not hard-code the server.
- Not covered yet: models on the `gsabss` and `billing` connections
  (`Employees`, `Buildings`, `p2m_oms_upload*`, and the `GSABSS.dbo.*`
  billing tables) read tables that `db/schema.rb` does not create. In CI
  those connections point at the `_CI` database.

## A green run

A green lint job takes about 4 minutes:

| Step | Time |
| ---- | ---- |
| Checkout code | about 7 s |
| Set up Ruby | about 2 min. Build tools take about 18 s; `bundle install` of 166 gems takes about 98 s. |
| Lint Ruby (RuboCop) | about 45 s, 1,399 files |
| Scan Rails security (Brakeman) | about 52 s, 0 warnings, 4 reviewed ignores |
| Audit Ruby dependencies (bundle-audit) | 2 to 5 s |

The runner picks up a queued job within seconds.

**The gem cache never hits.** `bundler-cache: true` saves a cache at the
end of `Set up Ruby`, but the cache key includes the job's work folder,
`C:\gitea-runner\work\<id>\hostexecutor`, and `<id>` changes on every
run. So every run installs all gems again, then saves a cache no later
run uses. See [Open items](#open-items).

**The bundle-audit advisory database persists.** The first run cloned
`ruby-advisory-db` into the service account's profile
(`C:\Users\svc-gitea-runner\.local\share\ruby-advisory-db`). Later runs
reuse it. `bundle-audit check` does not refresh it, so it goes stale
unless something updates it. See [Open items](#open-items).

## Line endings

Root `.gitattributes`:

| Pattern | Ending |
| ------- | ------ |
| `*.sh`, `bin/*`, `*.yml`, `*.yaml` | LF |
| `*.ps1`, `*.cmd`, `*.bat` | CRLF |

Git Bash breaks on CRLF shell scripts. `script/python/aim/.gitattributes`
already sets `*.bat` to CRLF for cmd.exe on GSA-SCAN02. The root rule
matches that for `*.bat`.

`.rubocop.yml` sets `Layout/EndOfLine` to `EnforcedStyle: lf` (#84,
PR #86). The default, `native`, means CRLF when RuboCop runs on
Windows. The repository is LF, so before #86 the runner reported one
offense per file (1,399) and the lint job stopped before Brakeman and
bundle-audit.

There is no `* text=auto` rule. Ruby, ERB, and Gemfile files carry no
text attribute, and the index holds no CRLF files, so with the runner's
`core.autocrlf=false` they check out as LF, byte for byte. If the
runner's Git were switched to `core.autocrlf=true`, those files would
check out as CRLF and RuboCop would fail again. A `* text=auto eol=lf`
rule would guard against that; it is not needed today.

## Tagging

`bin/tag-master-commit` uses `GITEA_SHA`, then `GITHUB_SHA`, then
`HEAD`. It reads `git config user.name` and `user.email` first. When
either value is empty and `GITEA_ACTIONS` or `GITHUB_ACTIONS` is
`true`, the tagger is `Paperboy CI` /
`paperboy-ci@noreply.invalid`. A workstation with no identity still
errors.

The tag job has not run on the runner yet. It needs `[lint, test]`, and
a job whose needed job is skipped is skipped too. While `CI_SQL_HOST`
is unset, `test` is skipped, so `master` pushes are not tagged. Run 172
(`b99e0ae2`) shows this: lint green, test and tag skipped, and no tag on
the remote for that commit. Pushing the tag needs the job token to have
`contents: write`. The workflow already sets that permission.

## Dependency updates

`.github/dependabot.yml` is removed. Dependabot does not run on Gitea,
so the file was inert. Renovate is a self-hosted option and is not
chosen.

## Locked platforms

`Gemfile.lock` locks `x64-mingw-ucrt` for the Windows runner. Ruby 4.0.6 on
Windows is a UCRT build. `x64-mingw32` is only Ruby 3.0 and older, so it is
not locked. No darwin platform was added. Windows builds of `google-protobuf`
4.36.2, `nokogiri` 1.19.4, and `sass-embedded` 1.105.0 were added at the same
versions as the Linux builds. No gem version changed. `tzinfo-data` 1.2026.5 is
locked; the Gemfile lists it for `platforms: %i[windows jruby]`.

Native gems with no Windows build compile with the MSYS2 build tools that
`setup-ruby` installs (the RubyInstaller DevKit layout): `tiny_tds` (it is
`force_ruby_platform`), bcrypt, bcrypt_pbkdf, bigdecimal, bootsnap, date,
debug, ed25519, erb, io-console, json, msgpack, nio4r, prism, puma, racc, rbs,
strscan, websocket-driver, and bindex. `tiny_tds` 3.4.0 compiles in the lint
job today; whether it connects to SQL Server is proven only when tests run.
`thruster` has no Windows build. The production server uses it, not CI.

## Answered questions

These were open before the runner went live.

1. **Runner label.** The runner registers `windows:host`, which Gitea
   lists as `windows`. `CI_RUNNER_LABEL` stays unset and the
   `runs-on` line stays as it is.
2. **`runs-on` expression.** Gitea 28.0.0 evaluates
   `${{ vars.CI_RUNNER_LABEL || 'windows' }}`. Runs 171 and 172 landed
   on `gsa-gitearunner`.
3. **Action source.** `uses:` actions download from GitHub. No mirror
   or absolute `uses: https://...` URL is needed.
4. **`.github` vs `.gitea` pickup.** Gitea picks up
   `.github/workflows/ci.yml` because the repository has no
   `.gitea/workflows`. Nothing moves.
5. **Runner owner.** Roy Morris owns the VM, the runner, and its
   service.

## Open items

Stage 2 (tests):

1. **Open: CI database and login.** Create `Paperboy_CI` on the test
   server and a CI login whose user is `db_owner` of that database only
   (no `CREATE ANY DATABASE`, no server roles). Then set `CI_SQL_HOST`
   (and `CI_SQL_PORT` / `CI_SQL_DATABASE` if they differ from the
   defaults) and the `CI_SQL_USERNAME` / `CI_SQL_PASSWORD` secrets. The
   gate stays `if: ${{ vars.CI_SQL_HOST != '' }}`.
2. **Open: FreeTDS.** `tiny_tds` builds today. Whether the runner needs
   its own FreeTDS install to connect is proven on the first test run.
3. **Open: Ruby+DevKit.** Whether to install RubyInstaller+DevKit on the
   runner instead of relying on `setup-ruby`'s download. Not needed while
   `setup-ruby` works as it does now.
4. **Open: Gary's self-hosted `setup-ruby` change.** Details with Gary.

Later:

5. **Open: tag job while tests are skipped.** No `master` commit is
   tagged until `test` runs. Either finish stage 2, or change the tag
   job's `if:` so a skipped `test` does not block it. Not decided.
6. **Open: gem cache.** The cache key changes on every run, so it never
   hits. Fixing it means a fixed work folder in the runner config or a
   different cache approach. Runner config is Roy's call.
7. **Open: advisory database refresh.** `bundle-audit check` does not
   update `ruby-advisory-db`. Options are `bundle-audit check --update`
   in the workflow or a scheduled update on the runner.
8. **Open: Chrome and system tests.** Run them once Chrome is on the
   runner? Then set `CI_SYSTEM_TESTS` to `true`. The step gate stays
   `if: ${{ vars.CI_SYSTEM_TESTS == 'true' }}`.
9. **Open: pin actions to commit SHAs.** Semgrep flags the mutable
   `@v4` / `@v1` tags. Run 172 resolved `actions/checkout@v4` to
   `11d5960a326750d5838078e36cf38b85af677262` and `ruby/setup-ruby@v1`
   to `14594264cd68ce8a2345dd349bc3d138a4ef85c8`.
10. **Open: required checks.** Which jobs must pass before a pull
    request can merge, and whether `master` gets branch protection.

# Unit Test Proposed Solutions

The `bin/unit-test` run recorded in `error.log` identified three categories of
issues: system-test failures, RuboCop offenses, and Brakeman warnings.

## 1. Fix the system tests first

`ProbationTransferRequestsTest` has three failures:

- `test_visiting_the_index`
- `test_visiting_the_new_request_form`
- `test_showing_an_existing_request`

Each failure reports that Capybara could not find an `h1`. The application
requires sign-in globally through `ApplicationController#require_sign_in`, but
the system test does not establish a browser session. The browser is therefore
likely rendering the signed-out landing page instead of the requested form.

Recommended changes:

1. Add or reuse a shared system-test sign-in helper.
2. Call the helper before visiting the probation-transfer routes.
3. Keep the production sign-in requirement enabled; do not bypass it merely to
   make the system test pass.
4. Update the show-test fixture so its `employee_id` matches the signed-in
   employee and satisfies submission-view access rules.

Run the focused test before the full suite:

```sh
PAPERBOY_TEST_DATABASE=Paperboy_Test bundle exec rails test \
  test/system/probation_transfer_requests_test.rb
```

Then run the repository's documented test command:

```sh
PAPERBOY_TEST_DATABASE=Paperboy_Test bundle exec rake test
```

Use another scratch SQL Server database if `Paperboy_Test` is unavailable. Do
not point tests at development, staging, or production data.

## 2. Resolve RuboCop offenses

The run found 9 offenses, 8 of which are autocorrectable.

### Safe corrections

Run the autocorrect command and inspect the resulting diff:

```sh
bundle exec rubocop -A
```

The Facebook publishing adapter has six hash-alignment offenses. The generated
textbook controller and the Solid migration each have a single-statement
disable/enable directive that should use `disable-next-line` instead.

If the textbook controller is generated, update its generator template as well
as the generated controller so the offense does not return.

### Class length

`P2m::StageDataController` exceeds the `Metrics/ClassLength` limit at 105/100
lines. Prefer moving file operations or action-specific behavior into a
service or focused controller concern. If the size is intentional, use a
narrow, documented RuboCop disable rather than suppressing an entire file.

## 3. Address Brakeman warnings

Brakeman reported four warnings: two possible SQL-injection warnings, one
dynamic evaluation warning, and one file-access warning. It also reported two
obsolete ignore entries.

### `P2m::QualityControl`

The SQL table and column names come from the frozen `SOURCES` allowlist and are
quoted, while date and OMS values are quoted as values. Preserve those
invariants. Where the database adapter supports it, use bound parameters for
value predicates rather than interpolating quoted values.

After verifying the allowlist and quoting behavior, either refactor until
Brakeman no longer warns or add a narrowly scoped ignore with a comment that
explains why the inputs are safe. Do not broadly ignore the SQL check.

### `DslCatalog`

`DslCatalog` evaluates Ruby files from the application DSL directory. The
preferred long-term solution is to migrate those definitions to a structured,
non-executable format such as YAML or JSON.

If Ruby DSL files are required, constrain evaluation to the trusted application
directory and an explicit set of files, document that those files are trusted
application code, and use only a narrowly scoped reviewed Brakeman ignore.

### `DataRunner::DslsController#output`

Before calling `send_file`, verify that the resolved path:

- is a regular file;
- is beneath the configured output root after canonicalization; and
- cannot escape through a symlink or path traversal.

Add traversal and symlink tests. Once the invariant is enforced, remove the
warning or add a narrowly scoped ignore if Brakeman still cannot prove it.

### Stale ignores

Review and remove the two obsolete hashes from `config/brakeman.ignore` after
confirming they do not correspond to current warnings.

## 4. Understand the audit results

`bundle-audit` reported:

```text
No vulnerabilities found
```

The four security warnings are Brakeman findings, not dependency
vulnerabilities. The test run ended with 3 failures and 0 errors, so the test
runner should remain nonzero until the system-test failures are fixed.

## Recommended implementation order

1. Fix system-test authentication and fixture authorization.
2. Apply and inspect RuboCop's safe autocorrections.
3. Refactor the class-length offense.
4. Harden or explicitly document each Brakeman finding.
5. Remove stale Brakeman ignores.
6. Run RuboCop, Brakeman, bundle-audit, and the full SQL Server-backed test
   suite.

## Proposed commit message

Review test and security failures

Document fixes for system tests, RuboCop offenses, and Brakeman warnings.

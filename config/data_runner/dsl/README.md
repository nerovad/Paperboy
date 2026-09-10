# DSL Dataset Files

This directory stores one `DSL_MAP` entry per file. Each entry lives under
the directory for its DSL group:

```text
config/data_runner/dsl/<dsl_group>/<dsl_name>.rb
```

DSLs that are not assigned to a group live under `other_dsls/`. When a DSL is
removed from a group, remove its `group` block and move it there. The `shared/`
directory contains shared SOP configuration and is not a DSL group.

## File Contract

Each file must evaluate to a two-element array:

```ruby
[
  'DatasetName',
  {
    # config hash
  }
]
```

- Element `0`: dataset key (`String`) used as the `DSL_MAP` key.
- Element `1`: dataset configuration (`Hash`).

If a file does not evaluate to `[String, Hash]`, loading will fail.

## Naming Convention

- Use lowercase snake_case filenames, for example:
  - `activities.rb`
  - `agency_funds.rb`
  - `vcprint.rb`
- Filename does not have to match the dataset key exactly, but keep them aligned for clarity.

## Load Behavior

`script/ruby/data_runner/commands/dsl_map.rb` loads all `*.rb` files in this directory in sorted
filename order and builds:

- `DSL_MAP = entries.to_h.freeze`

## Validation Performed by `script/ruby/data_runner/commands/dsl_map.rb`

- At least one DSL file must exist.
- Every file must return `[String, Hash]`.
- Dataset keys must be unique across all files.

## Editing Notes

- Keep changes scoped to the affected dataset file whenever possible.
- Configure manual and scheduled execution independently under `steps`.
  Each mode has its own `enabled` flag and step list.
- Use `manual: { enabled: true, steps: Workflow::MANUAL_STEPS }` for the full
  human workflow. Set `manual[:enabled]` to `false` when a DSL must not be run
  directly by a person.
- Use `scheduled: { enabled: true, frequency: :daily,
  steps: Workflow::SCHEDULED_STEPS }` for normal scheduled runs. Valid
  frequencies are `:daily`, `:weekly`, and `:monthly`.
- Set both mode-specific `enabled` flags to `false` to skip all manual and
  scheduled steps for a dataset.
- Use `group: { name: 'chart_of_accounts' }` to make a dataset selectable by
  group. Stage selectors may be omitted, a DSL name, or a group name; for
  example, `rake DataRunner:oneshot chart_of_accounts` processes all DSL
  entries in that group.
- Use a top-level `sop` to provide download instructions for any DSL:

```ruby
sop: {
  title: 'How to Download',
  source_system: 'External system',
  reference_url: 'https://example.test/reports',
  instructions: [
    'Sign in and open the report.',
    'Export the required period as CSV.',
    'Save the file in the DataRunner inbox.'
  ]
}
```

  `reference_url` is optional. Do not store credentials or secrets in an SOP.
  Use `reference_path` instead when users need to examine a server-mounted file
  or folder. Paperboy renders read-only details because browsers block local
  file links opened from web pages. Use `reference_title` to customize the
  dialog heading. Set `reference_path: :source_location` when the SOP should
  reference `source.location` without repeating the path. `reference_url`
  renders an **Open** link in a new tab, while `reference_path` renders a
  **View File** dialog; an SOP may use either or both. For HTTP downloads, set
  `reference_path: :downloaded_file` to view `01_Download/source.local`.
  Use `sop: { shared: :chart_of_accounts }` to import the shared Chart of
  Accounts refresh instructions and **View Group** link. Additional keys in
  that SOP object override or extend the shared definition in
  `dsl/shared/chart_of_accounts.rb`. The shared SOP also uses
  `reference_path: :downloaded_file`, so every group DSL can display its own
  `01_Download/source.local` file.
- Use `source.location` for the file or path to stage and `source.local` for
  the filename used inside `$DATARUNNER_INBOX` and downstream stages.
- Use `source.strategy: :manual` when a human places the file in `$DATARUNNER_INBOX`;
  if `source.location` differs from `source.local`, the download stage copies
  the placed file to the local staged name.
- Use `source.strategy: :copy` when the download stage should copy
  `source.location` into `$DATARUNNER_INBOX/source.local`.
- Use `source.strategy: :append` when a locally staged supplemental file should
  flow through the normal stages and append into another dataset's destination
  table via `inject.mode: :append`.
- Use top-level `dependency: 'Units'` when this DSL's injection must wait for
  another DSL's injection to succeed. During a parallel group refresh, the
  dependency must be included in the same run. DataRunner uses the shared run
  ID in `DataRunner_Log`, so an older successful injection cannot satisfy the
  dependency. A failed dependency fails the dependent DSL; a missing dependency
  or an hour-long wait raises an explicit error.
- Use `source.strategy: :script` when the download stage should run a local Ruby
  script that creates `$DATARUNNER_INBOX/source.local`:

```ruby
source: {
  location: nil,
  local: 'warehousing.csv',
  format: :csv,
  strategy: :script,
  script: {
    path: 'assemble_warehousing_data.rb',
    args: ['ALL']
  }
}
```

  Scripted sources must set `location: nil`; the script creates the file named
  by `source.local` in the DataRunner inbox.
- Use `source.strategy: :replicate` to export a SQL Server source table during
  the download stage. Put the source `host`, `database`, `schema`, and `table`
  in `source`; `database_connections` contains only replication targets. The
  imported target defaults to `inject.mode: :truncate_insert`.

- Use `database_connections: [...]` even when a dataset has only one destination.
  Each entry should include `host`, `database`, `schema`, `table`, and `inject`.
- Use `orchestration` on a control-only DSL when one download produces the
  canonical source files for several child DSLs. Each stage command expands
  the orchestrator into its children. `DataRunner:refresh` runs those same
  expanded stages in sequence and calls postprocessing only after every child
  inject succeeds:

```ruby
orchestration: {
  root_path: '/path/to/job',
  children: %w[FirstDataset SecondDataset],
  preprocessing: {
    enabled: true,
    args: [:root_path]
  },
  postprocessing: {
    enabled: true,
    args: [:root_path]
  }
}
```

  Lifecycle script paths are inferred from the DSL name. For example, `Oms`
  uses `orchestration/preprocess/oms.rb` and
  `orchestration/postprocess/oms.rb`. `download[orchestrator]` runs
  preprocessing and verifies every child output.
  `to_csv`, `use_dsl`, and `inject` expand to all children at the same stage.
  `dump_sql[orchestrator]` dumps every child table definition.
  `use_sql[orchestrator]` updates every child DSL from its reviewed SQL.
  `reset[orchestrator]` runs postprocessing and resets every child DSL.
  Symbol arguments resolve from the orchestration context.

- Replication (`source.strategy: :replicate`) copies source data using the
  configured destination mappings. Import setup skips `dump_sql` and `use_sql`;
  explicitly running those commands also skips replication entries. No source
  schema snapshot is created or applied. Configure destination headers for a
  new replication DSL before running it. Existing headers and destination
  `inject.post_script` settings are preserved. `to_sql` still generates the
  destination table definition from those headers when requested.

- Use `inject.post_script` when a destination should run a local Ruby script
  after its inject transaction commits:

```ruby
inject: {
  mode: :truncate_insert,
  post_script: {
    path: 'script/ruby/data_runner/after_dataset_inject.rb',
    args: ['ALL']
  }
}
```

  Post-inject script must live inside this repository. They receive target
  details in `DATARUNNER_*` environment variables.
- Prefer explicit arrays for header mappings, for example:
  - `['source_column', 'destination_column']`
  - `['source_column', nil]` to drop a column
  - `[nil, 'computed_column', 'nvarchar(50)', 'NULL', lambda { |row| row['first_name'] }]`
    to compute a value during `use_dsl`

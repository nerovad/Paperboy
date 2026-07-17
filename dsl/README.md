# DSL Dataset Files

This directory stores one `DSL_MAP` entry per file.

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
- Use `steps: { enabled: true, manual_steps: Workflow::MANUAL_STEPS, ... }` for
  the full human workflow.
- Set `steps: { enabled: false, ... }` to skip all manual and scheduled steps
  for a dataset.
- Use `steps: { scheduled: { frequency: :daily, steps: Workflow::SCHEDULED_STEPS } }`
  for normal scheduled runs. Valid frequencies are `:daily`, `:weekly`, and
  `:monthly`.
- Use `group: { name: 'chart_of_accounts' }` to make a dataset selectable by
  group. Stage selectors may be omitted, a DSL name, or a group name; for
  example, `rake DataRunner:oneshot chart_of_accounts` processes all DSL
  entries in that group.
- Use `source.location` for the file or path to stage and `source.local` for
  the filename used inside `01_Download` and downstream stages.
- Use `source.strategy: :manual` when a human places the file in `01_Download`;
  if `source.location` differs from `source.local`, the download stage copies
  the placed file to the local staged name.
- Use `source.strategy: :copy` when the download stage should copy
  `source.location` into `01_Download/source.local`.
- Use `source.strategy: :append` when a locally staged supplemental file should
  flow through the normal stages and append into another dataset's destination
  table via `inject.mode: :append`.
- Use `source.strategy: :script` when the download stage should run a local Ruby
  script that creates `01_Download/source.local`:

```ruby
source: {
  local: 'warehousing.csv',
  format: :csv,
  strategy: :script,
  script: {
    path: 'assemble_warehousing_data.rb',
    args: ['ALL']
  }
}
```

- Use `database_connections: [...]` even when a dataset has only one destination.
  Each entry should include `host`, `database`, `schema`, `table`, and `inject`.
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

# AI Instructions

- Generated Ruby conforms to `.rubocop.yml`.
- CI Pipeline requirements:
  * bundle exec rubocop
  * bundle exec brakeman
  * bundle exec bundle-audit check
  * bundle exec rake test
- Propose git commit message.
  * Prose limited to 72 characters
  * Blank Line
  * Description lines limited to 80 characters
- Git
  * use git mv when moving files

## Buttons

All action buttons use one shared system, defined in
`app/assets/stylesheets/components/_buttons.scss`. That file is the only
place button colours and sizes are declared.

Markup is always `.btn`, plus at most one colour variant and at most one
size modifier:

```erb
<%= link_to "View PDF", path, class: "btn pdf" %>
<%= button_to "Approve", path, method: :patch, class: "btn approve" %>
<button type="button" class="btn deny compact">Remove</button>
```

The inbox queue action row (`app/views/inbox/_dynamic_buttons.html.erb`)
is the reference implementation — new buttons should look like they
belong next to those.

Colour variants:

| Variant           | Use for                                   |
|-------------------|-------------------------------------------|
| *(none)*          | neutral secondary action (slate)          |
| `approve`         | confirm, save, submit, primary affirmative |
| `deny`            | reject, delete, destructive               |
| `pdf`, `secondary`| navigation / view actions (navy)          |
| `edit`, `warning` | edit, amend, caution (amber)              |
| `reassign`        | reassignment (blue)                       |
| `take-back`       | reclaim (teal)                            |
| `status-history`  | history / audit views (slate)             |
| `info`            | informational (cyan)                      |
| `close-panel`, `clear-filters` | quiet dismissals             |
| `ghost`           | lightest weight; light fill, dark text    |
| `active`          | selected item in a filter/toggle group    |

Size modifier: `compact` (also accepted: `btn-sm`).

Rules:

- Never invent a new `.btn` colour in a page stylesheet. Add the variant
  to `_buttons.scss` so it works app-wide, or reuse an existing one.
- Never write a bare `.btn` expecting a page rule to colour it. A `.btn`
  with no variant is already a complete, visible slate button.
- Page stylesheets may only adjust a button's *layout* (margin,
  alignment, grid placement) — never its background, text colour,
  height, padding, radius, or font.
- `btn-primary` / `btn-secondary` / `btn-danger` / `btn-info` are legacy
  aliases kept so old markup renders. Do not use them in new code.

Not part of this system, and deliberately styled on their own — leave
them alone:

- `.form-btn` / `.form-btn--*`: submit, next and back controls inside a
  form body.
- Profile dropdown entries (`.dropdown-content a`, `.logout-btn`): plain
  links styled by `layout/_header.scss`. Do not add `.btn` to them.
- Sidebar and nav links, `.information-trigger`, `.cc-trigger`,
  `.hamburger-btn`, and other one-off UI affordances.

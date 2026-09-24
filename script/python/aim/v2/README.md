# AIM v2 worker

One process that runs the whole AIM pipeline against the rows in
`aim.invoices` (the Paperboy database). Folders are storage, never status.

Each cycle it:

1. Takes in every file dropped under `Invoices/<BU>/<Name|SHARED>/`, moves
   the PDF to `_STORE/<batch_id>/`, and inserts a `received` row with
   `command = extract`.
2. Claims the oldest row with a command and does what it says: `extract`
   (AI read; the row becomes `needs_review`, `needs_split`,
   `ready_for_approval` or `failed`), `split` (children from the manifest),
   `export` (billing row, Laserfiche XML, archive copy; `exported`).

Every outcome clears the command and the lease and writes an event.

Run it with `Run_AIM_Worker.bat` from this folder. It reads `.env` beside it,
which `bin/deploy-aim-workers --v2` renders from LockBox; a missing variable
stops it at start. See `docs/aim/aim_plan.md`, "AIM v2 — The Row-First
Rebuild", for the contract it is built against.

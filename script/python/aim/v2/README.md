# AIM v2 worker

One process that runs the whole AIM pipeline against the rows in
`aim.invoices` (the Paperboy database). Folders are storage, never status.

Each cycle it:

1. Takes in every file dropped under `Invoices/<BU>/<Name|SHARED>/`, moves
   the PDF to `_STORE/<batch_id>/`, and inserts a `received` row with
   `command = extract`.
2. Claims the oldest row with a command and does what it says: `extract`
   (AI read; the row becomes `needs_review`, `needs_split`,
   `ready_for_approval` or `failed`), or `export` (billing row, Laserfiche
   XML, archive copy; `exported`). A split is cut by Paperboy when a person
   approves it (`Aim::BatchSplit`); the worker only reads the pieces. The
   `split` command (`splitting.py`) is legacy, kept for a Paperboy older
   than #192, and goes once none is left (wiki: AIM Alignment).

Every outcome clears the command and the lease and writes an event.

## A person can take an invoice from the AI (#192)

AIM staff can hold, skip, send, reject or delete an invoice in Waiting for AI,
even one the AI is reading. Paperboy makes the move and clears the row's
`command`, `lease_owner` and `lease_until`. The worker plays its part:

- Its lease name ends in `+stop` (`store.STOPPABLE`). Paperboy offers to take
  an invoice the AI is reading only from a worker whose lease says so
  (`Aim::InvoiceAiControl::STOPPABLE`); the two must stay the same.
- While it reads, every lease renewal and every write it makes carries
  `AND lease_owner = <its name>`. When a person has taken the row the update
  touches nothing and `store.Stopped` is raised: the worker stops at that
  point -- no more pages go to the model -- writes nothing, records no failure,
  and moves on.
- A held invoice is `received` with no command, so `claim_next` never takes it
  until Paperboy puts `extract` back.

A worker without `+stop` still runs; Paperboy simply refuses to take an
invoice from it while its lease is live. Deploy order does not matter.

Run it with `Run_AIM_Worker.bat` from this folder. It reads `.env` beside it,
which `bin/deploy-aim-workers --v2` renders from LockBox; a missing variable
stops it at start. See the [AIM Plan](http://10.135.204.125:3000/BSS/Paperboy/wiki/AIM-Plan)
wiki page, "AIM v2 — The Row-First Rebuild", for the contract it is built against.

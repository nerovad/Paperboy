# AIM Scan Center

This folder contains the Scan Center invoice-processing workers copied from
`\\gsa-scan02\AIM\_PROGRAM`.

Keep this code separate from the Rails portal:

- Rails portal: app UI, review workflow, controllers, services, and views in
  the normal Rails folders at the repo root.
- Scan Center: Python workers, Windows launchers, field mappings, vendor
  aliases, and queue-processing logic in this folder.

Pipeline settings are read from `.env`. For local repo development, keep that
file in the repository root. For server deployment, copy it either next to the
worker scripts in `_PROGRAM` or into the AIM root folder. You can also set
`AIM_ENV_FILE` to an explicit file path. Every pipeline setting is uppercase
and begins with `AIM_`.

The shared contract between Rails and Scan Center is the queue folder layout
and invoice metadata JSON shape. Changes to folder names, queue names, or JSON
fields should be made deliberately on both sides.

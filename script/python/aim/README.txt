================================================================================
AI INVOICE PROCESSING PIPELINE - README
================================================================================

OVERVIEW
--------------------------------------------------------------------------------
This project is an automated, AI-driven ETL (Extract, Transform, Load) pipeline 
designed to read incoming PDF invoices and statements, extract structured data 
(like Vendor Name, Invoice Number, Totals), generate XML for Laserfiche ingestion, 
and push tracking/billing data to a SQL database.

It uses a highly decoupled "Microservice" architecture to ensure speed, safely
handle batched PDFs containing multiple invoices, and prevent data loss if the 
SQL database goes offline.

THE FOLDER STRUCTURE
--------------------------------------------------------------------------------
The system is divided into three functional areas to keep things organized:

1. \_PROGRAM\      - Where the scripts and batch files reside.
2. \Invoices\      - The USER folder. Drop new PDFs here and find finished ones.
3. \_BACK_END\     - The SYSTEM folder. Holds processing queues, logs, and temp files.

THE COMPONENTS
--------------------------------------------------------------------------------
The workers and the .env file must be deployed together:

1. .env                - Master settings. AIM settings begin with AIM_.
2. pipeline_common.py  - The "Core Engine". Shared tools and database logic.
3. Python workers      - Queue, extraction, SQL, split, and alias processes.

For server deployment, place `.env` next to these worker scripts in _PROGRAM,
place it in the AIM root folder, or set AIM_ENV_FILE to the exact file path.
The Windows batch launchers check for this file before starting Python.

HOW TO RUN THE PIPELINE
--------------------------------------------------------------------------------
To run the system, launch these FIVE batch files on your server:
1. 01_Run_Fast_Lane.bat
2. 02_Run_Slow_Lane.bat
3. 03_Run_SQL_Worker.bat
4. 04_Run_Batch_Splitter.bat
5. 05_Run_Alias_Learner.bat

Once running, simply drop a PDF into a subfolder of your BaseDir 
(e.g., \Invoices\[BU#]\[SubmitterName]\invoice.pdf). The system handles the rest.

CONFIGURATION (.env)
--------------------------------------------------------------------------------
The system is configured with uppercase `AIM_` environment variables in `.env`.
These cover directories, filenames, SQL connections, mapping files, Tesseract,
and Rails path translation.

HOW TO ADDRESS ERRORS & MANUAL INTERVENTION
--------------------------------------------------------------------------------
1. UNKNOWN VENDORS (Alias Normalization)
   - PDF is moved to _VENDOR_REVIEW.
   - Edit the generated `{ID}_LEARN.json` with the correct name.
   - Drag it to _READY_TO_LEARN to teach the system.

2. HANDLING BATCHED INVOICES (Splitter)
   - PDF is moved to _BATCH_SPLIT.
   - Verify page ranges in the `{ID}_MANIFEST.json`.
   - Drag it to _READY_TO_SPLIT to trigger the physical split.

3. MISSING DATA (Action Needed)
   - PDF is moved to _ACTION_NEEDED.
   - Edit the `{ID}_READY_FOR_SQL.json` file to fill in missing fields.
   - Drag it to _SQL_QUEUE to push to the database.

TIPS AND TRICKS
--------------------------------------------------------------------------------
* DUPLICATE SAFE: The SQL database won't accept the same Processing ID twice.

* LOGGING: The system logs every action to the CSV file defined in AIM_LOG_FILE_NAME.
  Check this file if you need to troubleshoot why a specific document failed.

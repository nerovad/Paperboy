# frozen_string_literal: true

require 'pathname'

# workflow_paths.rb
#
# Single source of truth for workflow step folders.
# Scripts should reference these constants instead of hardcoding paths.

# {{{ Requrements and definitions

module WorkflowPaths
  ROOT = Pathname.new(__dir__).join('../../../..').expand_path

  # Folder names (stable contract)
  DOWNLOAD_DIR_NAME        = '01_Download'
  NORMALIZED_DIR_NAME      = '02_Normalized'
  SQL_MAP_DIR_NAME         = '03_SQL_MAP'
  SQL_SCHEMA_DIR_NAME      = '04_SQL_SCHEMA'
  APPLIED_DIR_NAME         = '05_DSL_Applied'
  DOWNLOAD_BACKUP_DIR_NAME = '06_Download_Backup'

  # Absolute paths (what scripts should actually use)
  DOWNLOAD_DIR        = (ROOT / DOWNLOAD_DIR_NAME).to_s
  NORMALIZED_DIR      = (ROOT / NORMALIZED_DIR_NAME).to_s
  SQL_MAP_DIR         = (ROOT / SQL_MAP_DIR_NAME).to_s
  SQL_SCHEMA_DIR      = (ROOT / SQL_SCHEMA_DIR_NAME).to_s
  APPLIED_DIR         = (ROOT / APPLIED_DIR_NAME).to_s
  DOWNLOAD_BACKUP_DIR = (ROOT / DOWNLOAD_BACKUP_DIR_NAME).to_s
end

# -------------------------------------------------------------------------- }}}

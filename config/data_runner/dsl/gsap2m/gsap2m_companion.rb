# frozen_string_literal: true

[
  'Gsap2m_companion',
  {
     steps: {
      manual: {
        enabled: true,
        steps: Workflow::REPLICATE_STEPS
      },
      scheduled: {
        enabled: false,
        frequency: :daily,
        steps: Workflow::REPLICATE_STEPS
      }
    },
    group: {
      name: 'gsap2m'
    },
    source: {
      host: 'GSASQL16.ent.co.ventura.ca.us',
      database: 'GSAP2M',
      schema: 'dbo',
      table: 'Companion',
      local: 'gsap2m_companion.csv',
      format: :csv,
      strategy: :replicate
    },
    to_csv: { sheet: 0, header_row: 0, data_row: 1 },
    header: [
      ['Budget 1 - Job ID', 'Budget 1 - Job ID', 'varchar(16)', 'NULL', nil],
      ['Budget 2 - Budget Unit', 'Budget 2 - Budget Unit', 'bigint', 'NULL', nil],
      ['Budget 3 - Activity', 'Budget 3 - Activity', 'varchar(100)', 'NULL', nil],
      ['Budget 4', 'Budget 4', 'varchar(100)', 'NULL', nil],
      ['Case Number', 'Case Number', 'varchar(100)', 'NULL', nil],
      ['Customer ID', 'Customer ID', 'varchar(100)', 'NULL', nil],
      ['District', 'District', 'varchar(100)', 'NULL', nil],
      ['Document Number', 'Document Number', 'varchar(100)', 'NULL', nil],
      ['Document Title', 'Document Title', 'varchar(100)', 'NULL', nil],
      ['Postal Address', 'Postal Address', 'varchar(200)', 'NULL', nil],
      ['Postal Address Last Line', 'Postal Address Last Line', 'varchar(100)', 'NULL', nil],
      ['Postal Address Line 1', 'Postal Address Line 1', 'varchar(100)', 'NULL', nil],
      ['Postal Address Line 2', 'Postal Address Line 2', 'varchar(100)', 'NULL', nil],
      ['Postal Address Line 3', 'Postal Address Line 3', 'varchar(100)', 'NULL', nil],
      ['Postal Address Line 4', 'Postal Address Line 4', 'varchar(100)', 'NULL', nil],
      ['Postal Address Line 5', 'Postal Address Line 5', 'varchar(100)', 'NULL', nil],
      ['Postal Address Line 6', 'Postal Address Line 6', 'varchar(100)', 'NULL', nil],
      ['Statement Number', 'Statement Number', 'varchar(100)', 'NULL', nil],
      ['Total Amount', 'Total Amount', 'varchar(100)', 'NULL', nil],
      ['AIMS job ID', 'AIMS job ID', 'varchar(100)', 'NULL', nil],
      ['AIMS mail piece ID', 'AIMS mail piece ID', 'varchar(100)', 'NULL', nil],
      ['AIMS status', 'AIMS status', 'varchar(100)', 'NULL', nil],
      ['Batch ID', 'Batch ID', 'bigint', 'NULL', nil],
      ['Communication piece file name', 'Communication piece file name', 'varchar(100)', 'NULL', nil],
      ['Communication piece ID', 'Communication piece ID', 'bigint', 'NULL', nil],
      ['Communication piece number', 'Communication piece number', 'bigint', 'NULL', nil],
      ['Communication profile name', 'Communication profile name', 'varchar(100)', 'NULL', nil],
      ['Container file name', 'Container file name', 'varchar(100)', 'NULL', nil],
      ['Container number', 'Container number', 'bigint', 'NULL', nil],
      ['Creation date', 'Creation date', 'varchar(100)', 'NULL', nil],
      ['Delivery type', 'Delivery type', 'varchar(100)', 'NULL', nil],
      ['Document profile names', 'Document profile names', 'varchar(100)', 'NULL', nil],
      ['Enclosures added', 'Enclosures added', 'bigint', 'NULL', nil],
      ['Envelope format', 'Envelope format', 'bigint', 'NULL', nil],
      ['Envelope name', 'Envelope name', 'varchar(max)', 'NULL', nil],
      ['Envelope number', 'Envelope number', 'bigint', 'NULL', nil],
      ['Envelope size', 'Envelope size', 'bigint', 'NULL', nil],
      ['File counter', 'File counter', 'bigint', 'NULL', nil],
      ['Input file names', 'Input file names', 'varchar(255)', 'NULL', nil],
      ['Input names', 'Input names', 'varchar(100)', 'NULL', nil],
      ['Number of pages', 'Number of pages', 'bigint', 'NULL', nil],
      ['Output file name', 'Output file name', 'varchar(100)', 'NULL', nil],
      ['Output name', 'Output name', 'varchar(100)', 'NULL', nil],
      ['Print on both sides', 'Print on both sides', 'varchar(100)', 'NULL', nil],
      ['Print or send time', 'Print or send time', 'varchar(100)', 'NULL', nil],
      ['Priority', 'Priority', 'varchar(100)', 'NULL', nil],
      ['Production workflow name', 'Production workflow name', 'varchar(100)', 'NULL', nil],
      ['Run production username', 'Run production username', 'varchar(100)', 'NULL', nil],
      ['Sorting parameters', 'Sorting parameters', 'varchar(100)', 'NULL', nil],
      ['Sorting type', 'Sorting type', 'varchar(100)', 'NULL', nil],
      ['Thickness', 'Thickness', 'float', 'NULL', nil],
      ['Total communication pieces in container', 'Total communication pieces in container', 'bigint', 'NULL', nil],
      ['Total documents', 'Total documents', 'bigint', 'NULL', nil],
      ['Total envelopes', 'Total envelopes', 'bigint', 'NULL', nil],
      ['Total pages in batch', 'Total pages in batch', 'bigint', 'NULL', nil],
      ['Total pages in communication piece', 'Total pages in communication piece', 'bigint', 'NULL', nil],
      ['Total pages in container', 'Total pages in container', 'bigint', 'NULL', nil],
      ['Total sheets', 'Total sheets', 'bigint', 'NULL', nil],
      ['Volume used', 'Volume used', 'bigint', 'NULL', nil],
      ['Weight', 'Weight', 'float', 'NULL', nil],
      ['OMSNumber', 'OMSNumber', 'int', 'NULL', nil],
      ['SourceFileName', 'SourceFileName', 'nvarchar(max)', 'NULL', nil],
      ['ID', 'ID', 'int', 'IDENTITY(0,1) NOT NULL', nil],
      ['ImportDateTime', 'ImportDateTime', 'datetime2(7)', 'NULL', nil]
    ],
    database_connections: [
      {
        host: 'gsa-sql22-tst.ent.co.ventura.ca.us',
        database: 'Paperboy',
        schema: 'p2m',
        table: 'Companion',
        inject: { mode: :truncate_insert }
      }
    ]
  }
]

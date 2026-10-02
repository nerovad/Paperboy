# frozen_string_literal: true

require 'test_helper'
require Rails.root.join('script/ruby/data_runner/helpers/etl_helpers')

class DataRunnerEtlHelpersTest < ActiveSupport::TestCase
  test 'builds a replication source independently from injection targets' do
    config = {
      source: {
        host: 'GSASQL16', database: 'GSA Scan', schema: 'dbo',
        table: 'Universal_Data_import', strategy: :replicate
      },
      database_connections: [
        { host: 'TARGETSQL', database: 'Reporting', schema: 'etl', table: 'UniversalData' }
      ]
    }

    source = EtlHelpers.source_database_target(config)
    target = EtlHelpers.database_targets(config).first

    assert_equal 'GSASQL16.GSA Scan.dbo.Universal_Data_import', source.label
    assert_equal 'TARGETSQL.Reporting.etl.UniversalData', target.label
  end

  test 'checks copy sources at their configured filesystem path' do
    Dir.mktmpdir do |directory|
      source = Pathname(directory).join('source.csv')
      source.write('source')

      assert EtlHelpers.source_file?(source)
      assert_not EtlHelpers.source_file?(source.sub_ext('.missing'))
    end
  end
end

# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class WorkflowOutputsTest < ActionDispatch::IntegrationTest
  test 'wildcard route preserves workflow output file extensions' do
    parameters = Rails.application.routes.recognize_path(
      '/data_runner/dsls/fiscalyears/outputs/05_DSL_Applied/fiscalyears.csv',
      method: :get
    )

    assert_equal '05_DSL_Applied/fiscalyears.csv', parameters[:path]
    assert_nil parameters[:format]
  end

  test 'units only includes files whose stem is exactly units' do
    Dir.mktmpdir('workflow-outputs-test') do |directory|
      root = Pathname(directory).join('output')
      inbox = Pathname(directory).join('inbox')
      paths = [inbox.join('units.xlsx'), root.join('02_Normalized', 'units.csv'),
               root.join('03_SQL_MAP', 'units.sql')]
      paths.each do |path|
        path.dirname.mkpath
        path.write('units')
      end

      entry = DslCatalog.find!('units')
      names = WorkflowOutputs.new(entry, root: root, inbox_root: inbox).files.map do |file|
        file.basename.to_s
      end

      assert_includes names, 'units.xlsx'
      assert_includes names, 'units.csv'
      assert_includes names, 'units.sql'
      assert(names.all? { |name| File.basename(name, '.*').casecmp?('units') })
      assert_not_includes names, 'sub_units.csv'
      assert_not_includes names, 'zyzzyva_units.csv'
    end
  end

  test 'backup files match timestamped exact DSL stems' do
    entry = DslCatalog.find!('units')
    backup_dir = Rails.root.join('output/data_runner/06_Download_Backup')
    unit_backup = backup_dir.join('2026-06-25-001-units.xlsx')
    sub_unit_backup = backup_dir.join('2026-06-25-001-sub_units.xlsx')
    backup_dir.mkpath
    unit_backup.write('unit backup')
    sub_unit_backup.write('sub unit backup')

    names = WorkflowOutputs.new(entry).backup_files.map { |file| file.basename.to_s }

    assert_includes names, '2026-06-25-001-units.xlsx'
    assert_not_includes names, '2026-06-25-001-sub_units.xlsx'
  ensure
    unit_backup&.delete if unit_backup&.file?
    sub_unit_backup&.delete if sub_unit_backup&.file?
  end
end

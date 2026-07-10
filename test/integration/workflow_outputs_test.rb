# frozen_string_literal: true

require "test_helper"

class WorkflowOutputsTest < ActionDispatch::IntegrationTest
  test "wildcard route preserves workflow output file extensions" do
    parameters = Rails.application.routes.recognize_path(
      "/data_runner/dsls/fiscalyears/outputs/05_DSL_Applied/fiscalyears.csv",
      method: :get
    )

    assert_equal "05_DSL_Applied/fiscalyears.csv", parameters[:path]
    assert_nil parameters[:format]
  end

  test "units only includes files whose stem is exactly units" do
    created_files = []
    [
      Rails.root.join("01_Download", "units.xlsx"),
      Rails.root.join("02_Normalized", "units.csv"),
      Rails.root.join("03_SQL_MAP", "units.sql")
    ].each do |path|
      next if path.file?

      path.dirname.mkpath
      path.write("units")
      created_files << path
    end

    entry = DslCatalog.find!("units")
    names = WorkflowOutputs.new(entry).files.map { |file| file.basename.to_s }

    assert_includes names, "units.xlsx"
    assert_includes names, "units.csv"
    assert_includes names, "units.sql"
    assert(names.all? { |name| File.basename(name, ".*").casecmp?("units") })
    assert_not_includes names, "sub_units.csv"
    assert_not_includes names, "zyzzyva_units.csv"
  ensure
    created_files&.each { |path| path.delete if path.file? }
  end

  test "backup files match timestamped exact DSL stems" do
    entry = DslCatalog.find!("units")
    backup_dir = Rails.root.join("06_Download_Backup")
    unit_backup = backup_dir.join("2026-06-25-001-units.xlsx")
    sub_unit_backup = backup_dir.join("2026-06-25-001-sub_units.xlsx")
    backup_dir.mkpath
    unit_backup.write("unit backup")
    sub_unit_backup.write("sub unit backup")

    names = WorkflowOutputs.new(entry).backup_files.map { |file| file.basename.to_s }

    assert_includes names, "2026-06-25-001-units.xlsx"
    assert_not_includes names, "2026-06-25-001-sub_units.xlsx"
  ensure
    unit_backup&.delete if unit_backup&.file?
    sub_unit_backup&.delete if sub_unit_backup&.file?
  end
end

# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

# Group and editor tests write catalog entries. Each process needs its own
# files, including when the catalog was loaded before Rails forked workers.
module IsolatedDslCatalog
  private

  # DSLs resolve application helpers relative to their original source path.
  def evaluation_path(path)
    Rails.root.join('config/data_runner/dsl', path.basename)
  end

  def directory
    return @test_dsl_directory if @test_dsl_pid == Process.pid

    @test_dsl_pid = Process.pid
    @test_dsl_directory = Pathname(Dir.mktmpdir('paperboy-test-dsls-'))
    FileUtils.cp_r(Rails.root.join('config/data_runner/dsl/.'), @test_dsl_directory)
    owner = Process.pid
    path = @test_dsl_directory
    at_exit { FileUtils.remove_entry(path) if Process.pid == owner && path.exist? }
    @test_dsl_directory
  end
end

DslCatalog.singleton_class.prepend(IsolatedDslCatalog)
DslCatalog.reload!

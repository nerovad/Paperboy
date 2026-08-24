# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'tmpdir'

class OmsOrchestrationTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join('../..').expand_path
  PREPROCESS = ROOT.join('script/ruby/data_runner/orchestration/preprocess/oms.rb')
  POSTPROCESS = ROOT.join('script/ruby/data_runner/orchestration/postprocess/oms.rb')

  def test_preprocesses_complete_staged_job_with_mail_date
    with_job do |sent, output, _processed|
      run_script(PREPROCESS, sent, output)

      %w[companions.csv dailypresorts.csv moveresults.csv].each do |name|
        rows = CSV.read(output.join(name), headers: true)
        assert_equal 2, rows.length
        assert_equal %w[omsnumber maildate importdatetime], rows.headers.first(3)
        assert_equal ['2026-08-21'], rows['maildate'].uniq
      end
    end
  end

  def test_archives_every_original_only_after_success
    with_job do |sent, output, processed|
      originals = sent.children.to_h { |path| [path.basename.to_s, path.binread] }

      run_script(POSTPROCESS, sent, output, processed)

      archive = processed.join('51780767')
      assert_equal originals.keys.sort, archive.children.map { |path| path.basename.to_s }.sort
      originals.each { |name, content| assert_equal content, archive.join(name).binread }
      assert_empty sent.children
    end
  end

  private

  def with_job
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      sent = root.join('00_SentToUSPS').tap(&:mkpath)
      output = root.join('01_TemporaryOutput').tap(&:mkpath)
      processed = root.join('02_Processed').tap(&:mkpath)
      marker = sent.join('Mail.dat_51780767.zip').tap { |path| path.binwrite('marker') }
      FileUtils.touch(marker, mtime: Time.new(2026, 8, 21, 12, 0, 0))
      write_companion(sent.join('51780767-000001-job.csv'))
      write_tsv(sent.join('Presort Fields Export_51780767.txt'), 'FLD_RECORD_ID')
      write_tsv(sent.join('MoveResults_51780767.txt'), 'RECORD_ID')
      sent.join('Postage Summary_51780767.pdf').binwrite('postal report')
      %w[companions.csv dailypresorts.csv moveresults.csv].each { |name| output.join(name).write('temporary') }
      yield sent, output, processed
    end
  end

  def write_companion(path)
    CSV.open(path, 'w') do |csv|
      csv << ['Budget 1 - Job ID', 'AIMS mail piece ID']
      csv << %w[RSPBLL piece-1]
      csv << %w[RSPBLL piece-2]
    end
  end

  def write_tsv(path, id_header)
    content = "#{id_header}\tNOTE\n1\tbare \"quote\n2\tok\n"
    path.binwrite(content.encode('UTF-16LE'))
  end

  def run_script(script, *args)
    output, status = Open3.capture2e(RbConfig.ruby, script.to_s, *args.map(&:to_s))
    assert status.success?, output
  end
end

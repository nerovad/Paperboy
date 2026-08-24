# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module P2m
  class OmsUploadLedgerTest < ActiveSupport::TestCase
    test 'records a staged job and retains its audit record after removal' do
      with_staged_job do |staging|
        ledger = OmsUploadLedger.new(staging_path: staging)
        upload = ledger.staged!(oms_number: '51780767', actor: 'operator@example.com')

        assert_equal Date.new(2026, 8, 21), upload.mailer_date
        assert_equal 'ready', upload.status
        assert_equal 2, upload.input_record_count
        assert_equal 1, upload.mailed_record_count
        assert_equal 1, upload.non_mailed_record_count
        assert_equal 4, upload.files.count
        assert_equal 'observed', upload.findings.find_by!(rule: 'non_mailed').status

        removed = false
        ledger.remove!(oms_number: '51780767', actor: 'operator@example.com') { removed = true }

        assert removed
        assert_equal 'removed', upload.reload.status
        assert_equal 4, upload.files.count
      end
    end

    test 'rejects removal after import begins' do
      with_staged_job do |staging|
        ledger = OmsUploadLedger.new(staging_path: staging)
        upload = ledger.staged!(oms_number: '51780767', actor: 'operator@example.com')
        upload.begin_import!

        assert_raises(OmsUploadLedger::ImportStarted) do
          ledger.remove!(oms_number: '51780767', actor: 'operator@example.com') { flunk }
        end
      end
    end

    test 'rejects staging an archived OMS number' do
      Dir.mktmpdir do |directory|
        processed = Pathname.new(directory)
        processed.join('51780767').mkpath
        ledger = OmsUploadLedger.new(staging_path: processed.join('staging'), processed_path: processed)

        assert_raises(OmsUploadLedger::ChangedFiles) do
          ledger.ensure_stageable!(oms_number: '51780767')
        end
      end
    end

    private

    def with_staged_job
      Dir.mktmpdir do |directory|
        staging = Pathname.new(directory)
        marker = staging.join('Mail.dat_51780767.zip').tap { |path| path.write('marker') }
        FileUtils.touch(marker, mtime: Time.new(2026, 8, 21, 12, 0, 0))
        write_companion(staging.join('51780767-000001-job.csv'))
        write_tsv(staging.join('Presort Fields Export_51780767.txt'), 'FLD_RECORD_ID', %w[0.5])
        write_tsv(staging.join('MoveResults_51780767.txt'), 'RECORD_ID', [])
        yield staging
      end
    end

    def write_companion(path)
      CSV.open(path, 'w') do |csv|
        csv << ['Budget 1 - Job ID', 'AIMS job ID', 'AIMS mail piece ID']
        csv << %w[RSPBLL job-1 piece-1]
        csv << %w[RSPBLL job-1 piece-2]
      end
    end

    def write_tsv(path, id_header, postage)
      content = CSV.generate(col_sep: "\t") do |csv|
        csv << [id_header, 'FLD_PIECE_POSTAGE']
        csv << ['1', postage.fetch(0, nil)]
        csv << ['2', nil]
      end
      path.binwrite(content.encode('UTF-16LE'))
    end
  end
end

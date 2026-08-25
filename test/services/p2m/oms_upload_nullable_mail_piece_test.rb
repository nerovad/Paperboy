# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module P2m
  class OmsUploadNullableMailPieceTest < ActiveSupport::TestCase
    test 'accepts null AIMS mail piece IDs' do
      with_staged_job do |staging|
        replace_mail_piece_ids(staging, [nil, nil])

        assert_nothing_raised do
          OmsUploadLedger.new(staging_path: staging).validate!(oms_number: '48831394')
        end
      end
    end

    test 'rejects duplicate populated AIMS mail piece IDs' do
      with_staged_job do |staging|
        replace_mail_piece_ids(staging, %w[piece-1 piece-1])

        error = assert_raises(OmsUploadLedger::InvalidDataset) do
          OmsUploadLedger.new(staging_path: staging).validate!(oms_number: '48831394')
        end
        assert_includes error.message, 'AIMS mail piece IDs must be unique.'
      end
    end

    private

    def with_staged_job
      Dir.mktmpdir do |directory|
        staging = Pathname.new(directory)
        staging.join('Mail.dat_48831394.zip').write('marker')
        write_companion(staging.join('48831394-000001-job.csv'))
        write_tsv(staging.join('Presort Fields Export_48831394.txt'), 'FLD_RECORD_ID')
        write_tsv(staging.join('MoveResults_48831394.txt'), 'RECORD_ID')
        yield staging
      end
    end

    def write_companion(path)
      CSV.open(path, 'w') do |csv|
        csv << ['Budget 1 - Job ID', 'AIMS mail piece ID']
        csv << %w[RSPBLL piece-1]
        csv << %w[RSPBLL piece-2]
      end
    end

    def replace_mail_piece_ids(staging, values)
      path = staging.join('48831394-000001-job.csv')
      rows = CSV.read(path)
      rows.drop(1).zip(values) { |row, value| row[1] = value }
      CSV.open(path, 'w') { |csv| rows.each { |row| csv << row } }
    end

    def write_tsv(path, id_header)
      content = CSV.generate(col_sep: "\t") do |csv|
        csv << [id_header, 'FLD_PIECE_POSTAGE']
        csv << %w[1 0.5]
        csv << ['2', nil]
      end
      path.binwrite(content.encode('UTF-16LE'))
    end
  end
end

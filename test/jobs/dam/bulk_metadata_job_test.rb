# frozen_string_literal: true

require 'test_helper'

module Dam
  # A bulk metadata edit sets what was filled in, clears what was ticked, and
  # leaves every other field on each asset alone.
  class BulkMetadataJobTest < ActiveSupport::TestCase
    setup do
      Dam::Job.delete_all
      Dam::MetadataValue.delete_all
      Dam::MetadataField.delete_all
      ActiveStorage::Attachment.delete_all
      ActiveStorage::Blob.delete_all
      Dam::Asset.delete_all
      %w[campaign rights owner].each do |key|
        Dam::MetadataField.create!(key: key, label: key.titleize, field_type: 'text', active: true)
      end
      @first = build_asset('First', rights: 'Internal', owner: 'Comms')
      @second = build_asset('Second', owner: 'Parks')
    end

    test 'sets, clears and leaves alone, then reports the run' do
      job = Dam::Job.enqueue!(job_type: 'metadata', total_items: 2, label: '2 assets')

      Dam::BulkMetadataJob.perform_now(job.id, [@first.id, @second.id], { 'campaign' => 'Summer', 'owner' => '' })

      assert_equal({ 'campaign' => 'Summer', 'rights' => 'Internal' }, values_of(@first))
      assert_equal({ 'campaign' => 'Summer' }, values_of(@second))
      job.reload
      assert_equal 'succeeded', job.status
      assert_equal 2, job.processed_items
      assert_match(/Updated 2 of 2/, job.log)
    end

    test 'a job that is no longer queued is not run again' do
      job = Dam::Job.enqueue!(job_type: 'metadata', total_items: 1)
      job.update!(status: 'cancelled')

      Dam::BulkMetadataJob.perform_now(job.id, [@first.id], { 'campaign' => 'Summer' })

      assert_nil values_of(@first)['campaign']
    end

    private

    def build_asset(title, **metadata)
      asset = Dam::Asset.new(title: title, media_type: 'image', storage_kind: 'stored',
                             content_type: 'image/jpeg', filename: "#{title}.jpg")
      asset.file.attach(io: StringIO.new('bytes'), filename: "#{title}.jpg", content_type: 'image/jpeg')
      metadata.each { |key, value| asset.metadata_values.build(field_key: key.to_s, value: value) }
      asset.save!
      asset
    end

    def values_of(asset)
      asset.reload.metadata_values.to_h { |row| [row.field_key, row.value] }
    end
  end
end

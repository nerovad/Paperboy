# frozen_string_literal: true

require 'test_helper'

module Dam
  # A value's typed columns are what the range filters compare, so a date may
  # only come from a field that holds dates — Time.zone.parse finds one in
  # almost any sentence.
  class MetadataValueTest < ActiveSupport::TestCase
    setup do
      Dam::MetadataValue.delete_all
      Dam::Asset.delete_all
      Dam::MetadataField.where(key: %w[shot_on caption rating]).delete_all
      Dam::MetadataField.create!(key: 'shot_on', label: 'Shot on', field_type: 'date')
      Dam::MetadataField.create!(key: 'caption', label: 'Caption', field_type: 'text')
      Dam::MetadataField.create!(key: 'rating', label: 'Rating', field_type: 'number')
      @asset = Dam::Asset.create!(title: 'An asset', media_type: 'image')
    end

    test 'a date field gets a date' do
      assert_equal Date.new(2017, 5, 30), value('shot_on', '2017-05-30 08:20:22').date_value.to_date
    end

    test 'text that happens to read as a date is not given one' do
      assert_nil value('caption', 'california, Julie Campbell Photography').date_value
    end

    test 'a year SQL Server cannot hold is dropped rather than refused' do
      assert_nil value('shot_on', 'iStock-1142533480.jpg').date_value
    end

    test 'a filename with a six-digit year in it is not a date either' do
      assert_nil value('shot_on', 'APPROVED_-_May_30_201701.jpg').date_value
    end

    test 'a number is still a number' do
      assert_in_delta 4.0, value('rating', '4').numeric_value
    end

    private

    def value(key, text) = @asset.metadata_values.create!(field_key: key, value: text)
  end
end

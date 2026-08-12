# frozen_string_literal: true

require 'test_helper'

module Billing
  class ArchiveLocationTest < ActiveSupport::TestCase
    test 'lists the archive root and its existing folders' do
      Dir.mktmpdir do |directory|
        root = Pathname(directory)
        root.join('FY27/AP01').mkpath

        assert_equal ['.', 'FY27', 'FY27/AP01'],
                     ArchiveLocation.all(root: root).map(&:relative_path)
      end
    end

    test 'rejects a location outside the configured choices' do
      Dir.mktmpdir do |directory|
        assert_raises(ActiveRecord::RecordNotFound) do
          ArchiveLocation.find('../outside', root: Pathname(directory))
        end
      end
    end
  end
end

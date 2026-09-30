# frozen_string_literal: true

require 'test_helper'

module Paperboy
  class SharePathTest < ActiveSupport::TestCase
    setup do
      @share = SharePath.new(windows_base: '\\\\gsa-scan01\\hsa\\Adoption_Cards', linux_base: '/mnt/a/HSA_Cards')
    end

    test 'a UNC path under the share becomes the mounted path' do
      assert_equal '/mnt/a/HSA_Cards/Folder/x.pdf', @share.to_linux('\\\\gsa-scan01\\hsa\\Adoption_Cards\\Folder\\x.pdf')
    end

    test 'the share prefix matches whatever its case, and the rest keeps its case' do
      assert_equal '/mnt/a/HSA_Cards/Folder/X.pdf', @share.to_linux('\\\\GSA-SCAN01\\HSA\\adoption_cards\\Folder\\X.pdf')
      assert_equal '/mnt/a/HSA_Cards/Folder/X.pdf', @share.to_linux('//Gsa-Scan01/Hsa/Adoption_Cards/Folder/X.pdf')
    end

    test 'only a leading base is replaced' do
      assert_nil @share.to_linux('\\\\other\\x\\gsa-scan01\\hsa\\Adoption_Cards\\x.pdf')
      assert_nil @share.to_windows('/backup/mnt/a/HSA_Cards/x.pdf')
    end

    test 'a sibling folder sharing the prefix is outside' do
      assert_nil @share.to_linux('\\\\gsa-scan01\\hsa\\Adoption_Cards_old\\x.pdf')
      assert_nil @share.to_windows('/mnt/a/HSA_Cards_old/x.pdf')
    end

    test 'the base itself translates to the other base' do
      assert_equal '/mnt/a/HSA_Cards', @share.to_linux('\\\\gsa-scan01\\hsa\\Adoption_Cards\\')
      assert_equal '\\\\gsa-scan01\\hsa\\Adoption_Cards', @share.to_windows('/mnt/a/HSA_Cards')
    end

    test 'a mounted path becomes the share path, matching the mount exactly' do
      assert_equal '\\\\gsa-scan01\\hsa\\Adoption_Cards\\Folder\\x.pdf', @share.to_windows('/mnt/a/HSA_Cards/Folder/x.pdf')
      assert_nil @share.to_windows('/MNT/A/hsa_cards/Folder/x.pdf')
    end

    test 'trailing separators on the bases are ignored' do
      share = SharePath.new(windows_base: 'E:\\AIM\\', linux_base: '/mnt/aim/')

      assert_equal '/mnt/aim/Store', share.to_linux('e:\\aim\\Store')
      assert_equal 'E:\\AIM\\Store', share.to_windows('/mnt/aim/Store')
      assert share.under_windows_base?('E:\\AIM\\x')
      assert_not share.under_windows_base?('F:\\AIM\\x')
    end
  end
end

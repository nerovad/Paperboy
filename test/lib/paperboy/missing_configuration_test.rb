# frozen_string_literal: true

require 'test_helper'

module Paperboy
  class MissingConfigurationTest < ActiveSupport::TestCase
    test 'each app names the variable to set, in its own error class' do
      aim = Aim::MissingConfiguration.for('AIM_STORE_DIR', 'The AIM store folder')
      hsa = HsaAdoptionCards::MissingConfiguration.for('HSA_ADOPT_LINUX_BASE_PATH', 'The scanned-cards mount')

      assert_equal 'The AIM store folder is not configured. Set AIM_STORE_DIR.', aim.message
      assert_equal 'The scanned-cards mount is not configured. Set HSA_ADOPT_LINUX_BASE_PATH.', hsa.message
      assert_instance_of Aim::MissingConfiguration, aim
      assert_kind_of HsaAdoptionCards::Error, hsa
      assert_not_kind_of HsaAdoptionCards::Error, aim
    end
  end
end

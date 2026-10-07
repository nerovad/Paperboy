# frozen_string_literal: true

require 'test_helper'

module P2m
  class UnusedStagingJobTest < ActiveSupport::TestCase
    SCREENS = [
      'app/controllers/p2m/pre_productions_controller.rb',
      'app/controllers/p2m/stage_data_controller.rb'
    ].freeze

    test 'the unused staging job is gone' do
      refute_path_exists Rails.root.join('app/services/p2m/stage_data.rb')
      refute_path_exists Rails.root.join('app/jobs/p2m/stage_data_job.rb')
      assert_raises(NameError) { StageData }
      assert_raises(NameError) { StageDataJob }
    end

    test 'the staging entry is not public' do
      refute PrintAndInsertingDone.respond_to?(:call)
      refute PrintAndInsertingDone.respond_to?(:run)
      assert PrintAndInsertingDone.respond_to?(:scan)
    end

    test 'mail dat screens search with scan only' do
      SCREENS.each do |relative|
        source = Rails.root.join(relative).read

        assert_includes source, 'PrintAndInsertingDone.scan', relative
        refute_includes source, 'PrintAndInsertingDone.call', relative
        refute_includes source, 'StageDataJob', relative
      end

      offenders = Rails.root.glob('{app,config}/**/*.{rb,yml}').select do |path|
        path.read.match?(/StageDataJob|P2m::StageData[^C]|StageData\.enqueue/)
      end
      assert_empty(offenders.map { |path| path.relative_path_from(Rails.root).to_s })
    end
  end
end

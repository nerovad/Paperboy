# frozen_string_literal: true

require 'test_helper'

module Billing
  class ReportGenerationJobTest < ActiveJob::TestCase
    test 'generates and writes print report artifacts' do
      artifacts = []
      generator = Minitest::Mock.new
      generator.expect(:call, artifacts)
      writer = Minitest::Mock.new
      writer.expect(:call, nil)

      ReportGenerator.stub(:new, generator) do
        ReportWriter.stub(:new, writer) do
          ReportGenerationJob.perform_now(
            operation: 'print', start_date: '2026-07-01', end_date: '2026-07-31', version: 1
          )
        end
      end

      assert_mock generator
      assert_mock writer
    end
  end
end

# frozen_string_literal: true

require 'test_helper'

# How a raw audited value is turned back into something a person can read. The
# date cases matter most: RecordEdit stores whatever string the column held, so
# an unhelped trail says `impact_started: 2026-09-15 00:00:00 -0700`.
module Forms
  class AuditValueTest < ActiveSupport::TestCase
    test 'a datetime column reads the way the Created column does' do
      value = Forms::AuditValue.new(model: CriticalInformationReporting)
                               .call('impact_started', '2026-09-15 00:00:00 -0700')

      assert_equal 'Sep 15, 2026 12:00 AM', value
    end

    test 'a date column is rendered without a clock it does not have' do
      value = Forms::AuditValue.new(model: CreativeJobRequest).call('date', '2026-09-02')

      assert_equal 'Sep 02, 2026', value
    end

    test 'a conventionally named date is still recognized with no model' do
      value = Forms::AuditValue.new.call('created_at', '2026-09-02 14:02:00 -0700')

      assert_equal 'Sep 02, 2026 02:02 PM', value
    end

    test 'a text column is left alone even when its name looks date-ish' do
      value = Forms::AuditValue.new(model: CreativeJobRequest).call('job_title', 'Graphic Designer')

      assert_equal 'Graphic Designer', value
    end

    test 'an unparseable date falls back to the stored value' do
      value = Forms::AuditValue.new(model: CriticalInformationReporting).call('impact_started', 'sometime')

      assert_equal 'sometime', value
    end

    test 'a blank value reads as empty' do
      assert_equal Forms::AuditValue::EMPTY,
                   Forms::AuditValue.new(model: CriticalInformationReporting).call('impact_started', nil)
    end
  end
end

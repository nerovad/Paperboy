# frozen_string_literal: true

require 'test_helper'

# The renamer decides what a duplicated form's code points at, so its one job
# is to rename the form's own identifiers and nothing that merely shares a
# prefix with them.
module Forms
  class Duplicator
    class RenamerTest < ActiveSupport::TestCase
      def renamer(companions: %w[SafetyReportsController SafetyReportPdfGenerator])
        Renamer.new(from_class: 'SafetyReport', to_class: 'SheriffSafetyReportingForm',
                    from_name: 'Safety Reporting', to_name: 'Sheriff Safety Reporting',
                    companions: companions)
      end

      test 'renames the class, its plural and the classes the copied files define' do
        text = renamer.text(<<~RUBY)
          class SafetyReportsController < Forms::BaseController
            def show = SafetyReport.find(params[:id])
            def pdf = SafetyReportPdfGenerator.generate(record)
          end
        RUBY

        assert_includes text, 'class SheriffSafetyReportingFormsController'
        assert_includes text, 'SheriffSafetyReportingForm.find'
        assert_includes text, 'SheriffSafetyReportingFormPdfGenerator.generate'
      end

      test 'leaves a class that only shares the prefix alone, and reports it' do
        subject = renamer
        text = subject.text('SafetyReportAuthorization.officer_ids_for_division(safety_report_authorizations)')

        assert_equal 'SafetyReportAuthorization.officer_ids_for_division(safety_report_authorizations)', text
        assert_equal ['SafetyReportAuthorization'], subject.untouched.to_a
      end

      test 'renames snake_case identifiers where the form name is whole words' do
        text = renamer.text('@safety_report = x; new_safety_report_path; safety_reports_path; set_safety_report')

        assert_equal '@sheriff_safety_reporting_form = x; new_sheriff_safety_reporting_form_path; ' \
                     'sheriff_safety_reporting_forms_path; set_sheriff_safety_reporting_form', text
      end

      test 'does not rename a snake word the form name only sits inside' do
        assert_equal 'unsafety_report_card', renamer.text('unsafety_report_card')
      end

      test 'renames the display name as a whole phrase, longest first' do
        assert_equal '<h1>Sheriff Safety Reporting</h1>', renamer.text('<h1>Safety Reporting</h1>')
        assert_equal 'Sheriff Safety Reporting Form data', renamer.text('Safety Report data')
      end

      test 'renames the class name inside a download file name' do
        assert_equal 'filename: "SheriffSafetyReportingForm_12.pdf"', renamer.text('filename: "SafetyReport_12.pdf"')
      end

      test 'renames the squeezed names Data Runner uses' do
        assert_equal "'Sheriffsafetyreportingforms', 'sheriffsafetyreportingforms.csv'",
                     renamer.text("'Safetyreports', 'safetyreports.csv'")
      end

      test 'renames file paths segment by segment' do
        assert_equal 'app/views/forms/sheriff_safety_reporting_forms/new.html.erb',
                     renamer.path('app/views/forms/safety_reports/new.html.erb')
        assert_equal 'app/controllers/forms/sheriff_safety_reporting_forms_controller.rb',
                     renamer.path('app/controllers/forms/safety_reports_controller.rb')
      end

      test 'never renames the result of a rename again' do
        subject = Renamer.new(from_class: 'SafetyReport', to_class: 'SheriffSafetyReport',
                              from_name: 'Safety Report', to_name: 'Sheriff Safety Report')

        assert_equal 'sheriff_safety_reports sheriff_safety_report SheriffSafetyReport',
                     subject.text('safety_reports safety_report SafetyReport')
      end
    end
  end
end

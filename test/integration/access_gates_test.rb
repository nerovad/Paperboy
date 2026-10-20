# frozen_string_literal: true

require 'test_helper'
require_relative '../support/access_gate_walk'

# Who may open a screen is a property of every route, not of each author's
# memory. Sign-in is the default (ApplicationController#require_sign_in), and
# so is the environment check; an access gate must stand in front of the
# action, or the route must be listed in config/access_gates.yml with a reason.
# A screen reachable by URL without one is how /lookup_tables, Data Runner and
# every page before sign-in became the default were once left open.
class AccessGatesTest < ActiveSupport::TestCase
  ALLOW_LIST = AccessGateWalk::AllowList.new
  STEPS = AccessGateWalk.steps

  test 'every route is covered by a gate or a row in config/access_gates.yml' do
    problems = STEPS.flat_map do |step|
      AccessGateWalk.problems(step, AccessGateWalk.controller_class(step), ALLOW_LIST)
    end

    assert_empty problems, problems.join("\n")
  end

  test 'every mounted application is listed' do
    unlisted = AccessGateWalk.mounted_paths - ALLOW_LIST.mounted_paths
    gone = ALLOW_LIST.mounted_paths - AccessGateWalk.mounted_paths

    assert_empty unlisted, "Mounted at #{unlisted.join(', ')} with no row under mounted: in config/access_gates.yml"
    assert_empty gone, "config/access_gates.yml lists #{gone.join(', ')} under mounted:, which is not mounted. Remove the row"
  end

  test 'every row says why and what protects the route' do
    rows = AccessGateWalk::AllowList::SECTIONS.flat_map { |section| ALLOW_LIST.rows(section) } + ALLOW_LIST.rows('mounted')
    missing = rows.reject { |row| row['reason'].present? && row['protected_by'].present? }

    assert_empty missing, "Rows without a reason and protected_by: #{missing.map(&:inspect).join('; ')}"
  end

  test 'a row never outlives the route or the gap it describes' do
    stale = AccessGateWalk::AllowList::SECTIONS.flat_map { |section| stale_rows(section) }

    assert_empty stale, stale.join("\n")
  end

  test 'a controller with no access gate is reported with the way to fix it' do
    problems = problems_for(Class.new(ApplicationController) { def show = head(:ok) }, 'show')

    assert_equal 1, problems.size
    assert_includes problems.first, 'has no access gate'
    assert_includes problems.first, "Inherit from the application's base controller"
    assert_includes problems.first, 'config/access_gates.yml'
  end

  test 'a controller that skips sign-in is reported with the way to fix it' do
    problems = problems_for(Class.new(ApplicationController) do
      skip_before_action :require_sign_in
      def show = head(:ok)
    end, 'show')

    assert_includes problems.first, 'is open to signed-out visitors'
    assert_includes problems.first, 'skip_before_action :require_sign_in'
  end

  test 'a controller with an access gate of its own is not reported' do
    gated = Class.new(ApplicationController) do
      before_action :require_the_right_group
      def show = head(:ok)

      private

      def require_the_right_group = head(:forbidden)
    end

    assert_empty problems_for(gated, 'show')
  end

  private

  # A controller that is on no route, named so the message reads like a real one.
  def problems_for(klass, action)
    klass.define_singleton_method(:name) { 'ThingsController' }
    step = AccessGateWalk::Step.new(verb: 'GET', path: '/things', controller: 'things', action: action, parts: [])
    AccessGateWalk.problems(step, klass, ALLOW_LIST)
  end

  # Rows that name a controller or action with no route, or one the described
  # gap no longer exists for.
  def stale_rows(section)
    ALLOW_LIST.rows(section).flat_map do |row|
      row.fetch('controllers').flat_map do |controller|
        actions = STEPS.select { |step| step.controller == controller }
        next ["#{section}: #{controller} has no route. Remove it from config/access_gates.yml."] if actions.empty?

        listed = row['actions'] || actions.map(&:action)
        (listed - actions.map(&:action)).map { |action| "#{section}: #{controller}##{action} has no route. Remove it from config/access_gates.yml." } +
          actions.select { |step| listed.include?(step.action) }.filter_map { |step| stale_reason(section, step) }
      end
    end
  end

  def stale_reason(section, step)
    klass = AccessGateWalk.controller_class(step)
    return (klass <= ApplicationController ? "framework: #{step.controller} inherits ApplicationController now. Remove the row." : nil) if section == 'framework'

    outcome = AccessGateWalk.outcome(klass, step)
    still_open = case section
                 when 'public' then outcome.signed_out_reaches?
                 when 'signed_in_only' then !outcome.gated?
                 when 'environment_exempt' then outcome.skips_environment_check?
                 end
    "#{section}: #{step.controller}##{step.action} is no longer open that way. Remove it from config/access_gates.yml." unless still_open
  end
end

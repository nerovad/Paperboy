# frozen_string_literal: true

# Reads the access gates the application puts in front of each route, for
# test/integration/access_gates_test.rb.
#
# To learn what protects one controller action it runs that controller's own
# callback chain with every named filter swapped for a recorder. Rails decides
# which filters apply (only:, except:, if:, unless:), so none of its rules are
# copied here, and no filter body runs: no query, no redirect, no render. A
# filter written as a block still runs, and the require_* gates it calls are
# recorders too. The answer is the list of filters that would run, in order.
module AccessGateWalk
  ALLOW_LIST_PATH = Rails.root.join('config/access_gates.yml')
  # A before_action with one of these names is an access gate, apart from the
  # two every ApplicationController action already runs.
  GATE_NAME = /\A(require_|authorize_)/
  BASE_FILTERS = %i[require_sign_in require_environment_access].freeze
  # require_* methods that check input, a second sign-in check or what the
  # person has set up, not what they are allowed to do.
  NOT_GATES = %i[require_login require_queue require_valid_rfc822_message require_search_or_browse].freeze
  FIX = "Inherit from the application's base controller or add it to config/access_gates.yml with a reason."

  Step = Data.define(:verb, :path, :controller, :action, :parts) do
    def label = "Route #{verb} #{path}"
  end

  # What would run before one action.
  Outcome = Data.define(:ran) do
    def reached? = ran.include?(:action)
    def signed_out_reaches? = reached? && ran.exclude?(:require_sign_in)
    def skips_environment_check? = reached? && ran.exclude?(:require_environment_access)
    # An action no filter lets through (a block that halts) is as good as gated.
    def gated? = !reached? || (ran.grep(GATE_NAME) - BASE_FILTERS - NOT_GATES).any?
  end

  module_function

  # One step per controller#action, in route order.
  def steps
    routes = Rails.application.routes.routes.select { |route| route.defaults[:controller] && route.defaults[:action] }
    routes.uniq { |route| route.defaults.values_at(:controller, :action) }.map do |route|
      Step.new(verb: route.verb, path: route.path.spec.to_s.delete_suffix('(.:format)'),
               controller: route.defaults[:controller], action: route.defaults[:action],
               parts: route.required_parts)
    end
  end

  # Paths of the Rack applications mounted without a controller.
  def mounted_paths
    Rails.application.routes.routes.reject { |route| route.defaults[:controller] }
         .map { |route| route.path.spec.to_s.delete_suffix('(.:format)') }.uniq
  end

  def controller_class(step) = "#{step.controller.camelize}Controller".constantize

  def outcome(klass, step)
    controller = klass.new
    request = ActionDispatch::TestRequest.create
    request.path_parameters = { controller: step.controller, action: step.action }
                              .merge(step.parts.to_h { |part| [part, '1'] })
    controller.set_request!(request)
    controller.set_response!(ActionDispatch::TestResponse.new)
    controller.action_name = step.action
    ran = []
    recorded_filters(klass).each do |name|
      controller.define_singleton_method(name) do |*|
        ran << name
        nil
      end
    end
    assumed_conditions(klass).each do |name, value|
      controller.define_singleton_method(name) { |*| value }
    end
    controller.run_callbacks(:process_action) { ran << :action }
    Outcome.new(ran: ran)
  end

  # The named filters of a controller, plus every access gate it defines, so a
  # gate called from inside a block is recorded instead of run.
  def recorded_filters(klass)
    named = klass._process_action_callbacks.reject { |callback| callback.kind == :around }.map(&:filter).grep(Symbol)
    gates = (klass.instance_methods + klass.private_instance_methods).grep(GATE_NAME).select do |name|
      klass.instance_method(name).source_location&.first.to_s.start_with?(Rails.root.join('app').to_s)
    end
    (named + gates).uniq
  end

  # A filter declared with if: :some_method? is a gate for some requests, and
  # some_method? may read the database. A gate counts when it is declared, so
  # each such condition is assumed to hold (an unless: condition not to). Rails
  # keeps these in instance variables of the callback; if it stops doing so
  # the conditions simply run for real.
  def assumed_conditions(klass)
    klass._process_action_callbacks.each_with_object({}) do |callback, assumed|
      Array(callback.instance_variable_get(:@if)).grep(Symbol).each { |name| assumed[name] = true }
      Array(callback.instance_variable_get(:@unless)).grep(Symbol).each { |name| assumed[name] = false }
    end
  end

  # Everything wrong with how one route is protected, as sentences that say
  # how to fix it. Empty when the route is covered.
  def problems(step, klass, allow_list)
    unless klass <= ApplicationController
      return [] if allow_list.covers?('framework', step)

      return ["#{step.label} (#{klass.name}##{step.action}) goes to a controller that does not inherit " \
              'ApplicationController, so none of its filters run. Inherit from it, or add it under framework: ' \
              'in config/access_gates.yml with a reason.']
    end

    outcome = outcome(klass, step)
    where = "#{step.label} (#{klass.name}##{step.action})"
    found = []
    if outcome.signed_out_reaches? && !allow_list.covers?('public', step)
      found << "#{where} is open to signed-out visitors. Remove the skip_before_action :require_sign_in, " \
               'or add it under public: in config/access_gates.yml with a reason.'
    end
    found << "#{where} has no access gate. #{FIX}" if ungated?(outcome, step, allow_list)
    if outcome.skips_environment_check? && !allow_list.covers?('environment_exempt', step)
      found << "#{where} skips the environment check. Remove the skip_before_action :require_environment_access, " \
               'or add it under environment_exempt: in config/access_gates.yml with a reason.'
    end
    found
  end

  def ungated?(outcome, step, allow_list)
    !outcome.signed_out_reaches? && !outcome.gated? && !allow_list.covers?('signed_in_only', step)
  end

  # config/access_gates.yml.
  class AllowList
    SECTIONS = %w[public signed_in_only environment_exempt framework].freeze

    def initialize(data = YAML.safe_load_file(ALLOW_LIST_PATH))
      @data = data
    end

    def rows(section) = @data.fetch(section)

    def mounted_paths = @data.fetch('mounted').pluck('path')

    def covers?(section, step)
      rows(section).any? do |row|
        row.fetch('controllers').include?(step.controller) && (row['actions'].nil? || row['actions'].include?(step.action))
      end
    end
  end
end

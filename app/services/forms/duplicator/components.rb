# frozen_string_literal: true

# app/services/forms/duplicator/components.rb

module Forms
  class Duplicator
    # The pieces of a form that Duplicate can copy, in the order they are
    # offered. Each is one checkbox on the duplicate dialog.
    #
    # +requires+ lists what a piece cannot work without, so the dialog ticks
    # those alongside it and the server refuses a set that leaves one out: a
    # copied controller that renders views nobody copied is a form that 500s.
    # The form definition is the copy itself, so it is always included.
    #
    # Stylesheets and Stimulus controllers are not listed: none is per-form,
    # they are shared by class name, so copied views keep using them. Mail
    # goes through the shared FormWorkflowMailer, keyed by class name, and
    # follows the copied workflow emails.
    module Components
      Component = Data.define(:key, :label, :description, :requires, :locked) do
        def locked? = locked
      end

      ALL = [
        Component.new(
          key: 'definition', label: 'Form builder definition', locked: true, requires: [],
          description: 'Settings, pages, tags and every field with its dropdowns, conditions and restrictions.'
        ),
        Component.new(
          key: 'workflow', label: 'Approval workflow', locked: false, requires: [],
          description: 'Statuses, routing steps, workflow emails, copy recipients and inbox buttons.'
        ),
        Component.new(
          key: 'access', label: 'ACL access', locked: false, requires: [],
          description: 'Every group and org scope that can open this form can open the copy.'
        ),
        Component.new(
          key: 'visibility', label: 'Visibility grants & subscriptions', locked: false, requires: [],
          description: 'Who can see other people’s submissions, and who is emailed about them.'
        ),
        Component.new(
          key: 'sidebar', label: 'Sidebar link', locked: false, requires: %w[controller],
          description: 'List the copy in the sidebar. Left unticked, the copy starts archived.'
        ),
        Component.new(
          key: 'table', label: 'Database table', locked: false, requires: [],
          description: 'A new table with every column and index of the original, but no submissions.'
        ),
        Component.new(
          key: 'model', label: 'Model', locked: false, requires: %w[table workflow],
          description: 'The model class, plus the models behind any repeating sections.'
        ),
        Component.new(
          key: 'controller', label: 'Controller & routes', locked: false, requires: %w[model views pdf],
          description: 'The controller and every route that points at it.'
        ),
        Component.new(
          key: 'views', label: 'Views', locked: false, requires: [],
          description: 'The new, edit, show and any other templates for the form.'
        ),
        Component.new(
          key: 'pdf', label: 'PDF generator', locked: false, requires: [],
          description: 'The service behind the View PDF button.'
        ),
        Component.new(
          key: 'data_runner', label: 'Data Runner export', locked: false, requires: %w[table],
          description: 'The Data Runner DSL that loads the table, pointed at the new one with its schedule paused.'
        )
      ].freeze

      KEYS = ALL.map(&:key).freeze

      module_function

      def find(key)
        ALL.find { |component| component.key == key.to_s }
      end

      # The requested keys plus the locked ones, restricted to known keys.
      def normalize(keys)
        wanted = Array(keys).map(&:to_s)
        KEYS.select { |key| wanted.include?(key) || find(key).locked? }
      end

      # Human-readable complaints for each chosen piece whose requirements
      # were left out. Empty when the set stands on its own. A requirement the
      # form has nothing for (+unavailable+ -- say, no PDF generator) cannot be
      # ticked, so it does not count against the set.
      def missing_requirements(keys, unavailable = [])
        keys.flat_map do |key|
          (find(key).requires - keys - unavailable).map do |needed|
            "#{find(key).label} needs #{find(needed).label} — tick both or neither."
          end
        end
      end
    end
  end
end

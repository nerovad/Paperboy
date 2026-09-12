# frozen_string_literal: true

# app/services/forms/duplicator.rb

require 'open3'

module Forms
  # Copies a form under a new name: its builder definition and whichever of
  # its workflow, access, table, code and exports the admin ticks (see
  # Components). Everything copied is renamed -- the template, class, table,
  # controller, views, routes and file names all follow the new name, so the
  # copy is a separate form that can drift from the original freely.
  #
  #   dup = Forms::Duplicator.new(source: template, name: 'Sheriff Safety Reporting',
  #                               components: Forms::Duplicator::Components::KEYS)
  #   dup.valid?  # => false, dup.errors explains
  #   dup.preview # what lands where, for the dialog
  #   dup.call    # => Result(template:, notes:)
  #
  # Order matters for recovery. Rows are written in one transaction, then
  # files, then the migration runs last; if any step fails, the files are put
  # back, the rows deleted, and the error re-raised, so a failed duplicate
  # leaves nothing behind.
  class Duplicator
    class Error < StandardError; end

    Result = Data.define(:template, :notes)

    CLASS_NAME = /\A[A-Z][A-Za-z0-9]*\z/

    attr_reader :source, :name, :errors

    def initialize(source:, name:, components:, actor_id: nil, runner: nil)
      @source = source
      @name = name.to_s.squish
      @requested = components
      @actor_id = actor_id
      @runner = runner || ->(*args) { Open3.capture2e('bin/rails', *args, chdir: Rails.root.to_s) }
      @errors = []
    end

    def class_name = Forms::Template.class_name_for(name)

    # Whether the name typed so far makes a usable class. Until it does the
    # preview shows what is being copied and a blank for where it goes.
    def named? = name.present? && class_name.match?(CLASS_NAME)

    def valid?
      @errors = []
      validate_name
      validate_components
      validate_targets if @errors.empty?
      @errors.empty?
    end

    def call
      raise Error, errors.join(' ') unless valid?

      journal = Journal.new
      template = ActiveRecord::Base.transaction { definition_copier.call }
      code.call(journal)
      tables.call if copies?('table')
      Result.new(template: template, notes: notes)
    rescue StandardError
      journal&.rollback!
      Cleanup.new(template).call if template
      raise
    end

    def preview
      Preview.new(self).to_h
    end

    # The ticked components the form actually has something for.
    def components
      @components ||= Components.normalize(@requested) - unavailable
    end

    def unavailable
      @unavailable ||= Preview.new(self).unavailable
    end

    def copies?(key) = components.include?(key)

    def renamer
      @renamer ||= Renamer.new(from_class: source.class_name, to_class: class_name,
                               from_name: source.name, to_name: name,
                               companions: CodeCopier.companions_for(source))
    end

    def code
      @code ||= CodeCopier.new(source: source, renamer: renamer, components: components)
    end

    def tables
      @tables ||= TableCopier.new(source_tables: source_tables, renamer: renamer, runner: @runner)
    end

    # The form's table and its repeating-section child tables, as they exist.
    def source_tables
      @source_tables ||= [source_table, *source.repeating_sections.filter_map(&:section_association_name)]
                         .select { |table| connection.data_source_exists?(table) }
    end

    # The table the form's model actually reads, which a hand-written model
    # may have pointed somewhere other than the class-name default.
    def source_table
      source.class_name.safe_constantize.try(:table_name) || source.table_name
    end

    private

    def connection = ActiveRecord::Base.connection

    def definition_copier
      DefinitionCopier.new(source: source, name: name, components: components, actor_id: @actor_id,
                           renamer: renamer)
    end

    def validate_name
      return @errors << 'Give the copy a name.' if name.blank?
      return @errors << 'The name must start with a letter.' unless named?

      @errors << "A form named “#{name}” already exists — pick a different name." if name_taken?
      @errors << "A form class #{class_name} already exists — pick a different name." if class_taken?
    end

    # Forms are looked up by name in the sidebar, the ACL screen and the
    # submissions filter, so two forms may not share one.
    def name_taken?
      names = Forms::Template.pluck(:name) + FormCatalog::LEGACY_FORMS.pluck(:name) +
              AclController::LEGACY_FORMS.pluck(:label)
      names.compact.map(&:downcase).include?(name.downcase)
    end

    def class_taken?
      Forms::Template.exists?(class_name: class_name) || class_name.safe_constantize.present?
    end

    def validate_components
      @errors.concat(Components.missing_requirements(components, unavailable))
    end

    # Nothing the copy writes may already be there.
    def validate_targets
      tables.target_tables.each do |table|
        @errors << "Table #{table} already exists." if copies?('table') && connection.data_source_exists?(table)
      end
      code.file_pairs.map(&:last).each do |to|
        @errors << "#{to} already exists." if Rails.root.join(to).exist?
      end
      @errors << "config/routes.rb already has resources :#{class_name.underscore.pluralize}." if route_taken?
    end

    def route_taken?
      pattern = /^\s*resources :#{class_name.underscore.pluralize}\b/
      code.routes? && Rails.root.join(CodeCopier::ROUTES).read.match?(pattern)
    end

    def notes
      Notes.new(self).to_a
    end
  end
end

# frozen_string_literal: true

# app/services/forms/duplicator/code_copier.rb

module Forms
  class Duplicator
    # Copies the files half of a form -- model, controller, views, PDF
    # generator, Data Runner DSL -- renaming each file and everything inside
    # it, and copies the form's block in config/routes.rb.
    #
    # The source files are copied rather than regenerated because most forms
    # have been edited by hand since the builder wrote them: the Safety
    # Report's controller permits fields the generator never lists, and its
    # views carry custom blocks the builder only preserves from an existing
    # file. A copy keeps all of that; regeneration would quietly drop it.
    #
    # Stylesheets and Stimulus controllers are not per-form here -- they are
    # shared by class name and identifier -- so copied views keep using them
    # without anything being copied.
    class CodeCopier
      ROUTES = 'config/routes.rb'

      def initialize(source:, renamer:, components:)
        @source = source
        @renamer = renamer
        @components = components
      end

      # [source relative path, destination relative path] for every file the
      # chosen components copy.
      def file_pairs
        @file_pairs ||= @components.flat_map { |key| files_for(key) }
                                   .uniq
                                   .map { |path| [path, @renamer.path(path)] }
      end

      # Files that exist for +key+, relative to the app root. Empty when the
      # form has none (older forms have no PDF generator, most no DSL).
      def files_for(key)
        case key.to_s
        when 'model' then existing([model_file, *section_model_files])
        when 'controller' then existing(["app/controllers/forms/#{plural}_controller.rb"])
        when 'views' then view_files
        when 'pdf' then existing(["app/services/#{file}_pdf_generator.rb"])
        when 'data_runner' then data_runner_files
        else []
        end
      end

      def routes? = @components.include?('controller')

      # The source's resources block in config/routes.rb, or nil when routes
      # are not being copied or the form has no block to copy.
      def routes_block
        return nil unless routes?

        @routes_block ||= find_routes_block(read(ROUTES))
      end

      # Writes every copy. +journal+ records each file created or changed so a
      # failure later on can put the tree back.
      def call(journal)
        file_pairs.each do |from, to|
          journal.create_file(to, transform(from, read(from)))
        end
        copy_routes(journal) if routes_block
      end

      # Classes defined by a form's own Ruby files. Renaming these (and only
      # these) keeps a copy from pointing at classes that belong to someone
      # else, like SafetyReportAuthorization. Read from every file the form
      # has, not just the ticked ones, so the rename is the same whatever is
      # copied.
      def self.companions_for(source)
        scanner = new(source: source, renamer: nil, components: [])
        %w[model controller pdf].flat_map { |key| scanner.files_for(key) }
                                .flat_map { |path| Rails.root.join(path).read.scan(/^\s*class\s+(?:\w+::)*(\w+)/).flatten }
                                .select { |name| name.start_with?(source.class_name) }
                                .uniq
      end

      private

      def file = @source.file_name
      def plural = @source.plural_file_name
      def model_file = "app/models/#{file}.rb"

      def section_model_files
        @source.repeating_sections.filter_map do |section|
          assoc = section.section_association_name
          "app/models/#{assoc.singularize}.rb" if assoc
        end
      end

      def view_files
        dir = Rails.root.join('app/views/forms', plural)
        Dir.glob(dir.join('**/*')).select { |path| File.file?(path) }.map { |path| relative(path) }.sort
      end

      # The DSL that loads the form's table, found by its target rather than
      # its file name.
      def data_runner_files
        target = /table:\s*['"]#{Regexp.escape(@source.table_name)}['"]/
        Dir.glob(Rails.root.join('config/data_runner/dsl/**/*.rb'))
           .select { |path| File.read(path).match?(target) }
           .map { |path| relative(path) }
           .sort
      end

      def existing(paths)
        paths.select { |path| Rails.root.join(path).file? }
      end

      def relative(path)
        Pathname(path).relative_path_from(Rails.root).to_s
      end

      def read(path)
        Rails.root.join(path).read
      end

      def transform(from, content)
        renamed = @renamer.text(content)
        from.start_with?('config/data_runner/') ? pause_schedule(renamed) : renamed
      end

      # A form's DSL truncates and reloads its table. Copied live, it would
      # empty the new form's table every morning, so the copy starts paused.
      def pause_schedule(content)
        content.sub(/(scheduled:\s*\{\s*\n\s*enabled:\s*)true(,?)/) do
          "#{::Regexp.last_match(1)}false#{::Regexp.last_match(2)} # paused by Duplicate: this DSL truncates the table it loads"
        end
      end

      # `resources :safety_reports ...` through its matching `end` (or the one
      # line when it has no block), with the indentation it was written at.
      def find_routes_block(routes)
        lines = routes.lines
        start = lines.index { |line| line.match?(/^\s*resources :#{Regexp.escape(plural)}\b/) }
        return nil unless start

        head = lines[start]
        return head unless head.rstrip.end_with?(' do')

        indent = head[/\A\s*/]
        finish = ((start + 1)...lines.size).find { |i| lines[i].match?(/\A#{indent}end\b/) }
        finish ? lines[start..finish].join : nil
      end

      # The copy goes straight after the original, so the two stay together.
      def copy_routes(journal)
        routes = read(ROUTES)
        block = routes_block
        journal.update_file(ROUTES, routes.sub(block) { "#{block}#{@renamer.text(block)}" })
      end
    end
  end
end

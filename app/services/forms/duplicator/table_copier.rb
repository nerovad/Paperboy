# frozen_string_literal: true

# app/services/forms/duplicator/table_copier.rb

module Forms
  class Duplicator
    # Writes and runs the migration that gives a copied form its own tables:
    # the submissions table and one child table per repeating section, each
    # with every column and index the original has today.
    #
    # The builder never adds a field's column to a form's table, so the columns
    # a form actually has live only in the database (the Safety Report gained
    # thirteen of them by hand-written migration). Regenerating from the
    # template would lose them; instead each table is described by the same
    # schema dumper that writes db/schema.rb, so the copy matches the original
    # column for column, and then renamed. No rows are copied.
    class TableCopier
      def initialize(source_tables:, renamer:, runner:)
        @source_tables = source_tables
        @renamer = renamer
        @runner = runner
      end

      def target_tables
        @source_tables.map { |table| @renamer.text(table) }
      end

      # Relative path of the migration this will write, fixed once computed so
      # the preview and the file agree.
      def migration_path
        @migration_path ||= "db/migrate/#{stamp}_#{slug}.rb"
      end

      # Writes the migration and runs db:migrate. On failure the file is removed
      # again -- a pending migration left behind blocks every request -- and
      # the migrator's output is raised.
      def call
        path = Rails.root.join(migration_path)
        File.write(path, migration_source)
        output, status = @runner.call('db:migrate')
        return path if status.success?

        FileUtils.rm_f(path)
        raise Error, "db:migrate failed: #{output.to_s.lines.last(15).join}"
      end

      def migration_source
        <<~RUBY
          # frozen_string_literal: true

          # Created by Duplicate on the form builder: #{target_tables.join(', ')}, copied
          # column for column from #{@source_tables.join(', ')}.
          class #{slug.camelize} < ActiveRecord::Migration[#{ActiveRecord::Migration.current_version}]
            def change
          #{@source_tables.map { |table| table_block(table) }.join("\n")}
            end
          end
        RUBY
      end

      private

      def stamp
        @stamp ||= Time.now.utc.strftime('%Y%m%d%H%M%S')
      end

      # The stamp is part of the class name too: a form once created and
      # deleted under this name left its create_<table> migration behind, and
      # two migrations sharing a class name abort db:migrate.
      def slug
        "create_#{target_tables.first}_#{stamp}"
      end

      # The create_table block schema.rb holds for +table+, renamed and
      # indented into the migration's change method.
      def table_block(table)
        io = StringIO.new
        # SchemaDumper#table is private, but it is the one place the adapter's
        # own mapping of SQL Server types back to migration DSL lives; the
        # duplicator test pins its output shape.
        ActiveRecord::Base.connection.create_schema_dumper({}).send(:table, table, io)
        block = io.string.sub(', force: :cascade', '').sub(/\A\n+/, '').rstrip
        @renamer.text(block).lines.map { |line| "  #{line.rstrip}".rstrip }.join("\n")
      end
    end
  end
end

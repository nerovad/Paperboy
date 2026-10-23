# frozen_string_literal: true

# Merges live source columns into a replication DSL header.
# A second run is a no-op when the merged rows already match the file.
# The caller writes a temporary file and renames it over the DSL, so a crash
# before that rename leaves the original file in place.
module DataRunner
  module ReplicationHeader
    module_function

    def merge(existing, columns)
      indexed = index(existing)
      columns.map { |column| row_for(column, indexed[column.fetch(:name)]) } + expressions(existing)
    end

    def unchanged?(existing, rows)
      normalize(existing) == rows
    end

    def normalize(existing)
      Array(existing).map { |row| tuple(row) }
    end

    def index(existing)
      Array(existing).each_with_object({}) do |row, indexed|
        source = row[0]
        next if source.nil? || source.to_s.strip.empty?

        indexed[source.to_s] = row
      end
    end

    def row_for(column, prior)
      name = column.fetch(:name)
      data_type = column.fetch(:data_type)
      nullability = column.fetch(:nullability)
      return [name, name, data_type, nullability, nil] if prior.nil?

      [prior[0], prior[1], data_type, nullability, prior[4]]
    end

    def expressions(existing)
      Array(existing).select { |row| row[0].nil? || row[0].to_s.strip.empty? }.map { |row| tuple(row) }
    end

    def tuple(row)
      input, output, data_type, nullability, default_value = row
      [input, output, data_type, nullability, default_value]
    end
    private_class_method :index, :row_for, :expressions, :tuple
  end
end

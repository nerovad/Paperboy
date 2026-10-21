# frozen_string_literal: true

module Paperboy
  module Pdf
    # Bates-stamps one or more PDFs in order, numbering continuously across
    # them: the first page of the second file takes the number after the
    # last page of the first. Each file is stamped with +areas+ (StampAreas),
    # filled with +values+ and each page's Bates fields. Nothing is written;
    # the caller gets each file's bytes, the numbers used, and the safety
    # nets any page needed.
    class BatesRun
      Result = Data.define(:files, :first_number, :last_number, :pages, :warnings)

      def initialize(bates, areas, values: {}, shrink: nil)
        @bates = bates
        @areas = areas
        @values = values
        @shrink = shrink
      end

      # +paths+: the PDFs, in order. Raises Unwritable for one that cannot be
      # read, naming nothing stamped.
      def stamp(paths)
        number = @bates.start
        warnings = {}
        files = paths.each_with_index.map do |path, file_index|
          stamper = Stamp.new(path)
          first = number
          result = stamper.render(shrink: @shrink) do |index, count|
            StampAreas.boxes(@areas, @values.merge(@bates.page_values(first + index, index + 1, count)))
          end
          warnings[file_index + 1] = result.warnings if result.warnings.any?
          number += stamper.page_count
          result.bytes
        end
        Result.new(files: files, first_number: @bates.start, last_number: number - 1, pages: number - @bates.start,
                   warnings: warnings)
      end
    end
  end
end

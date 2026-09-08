# frozen_string_literal: true

module Aim
  # Source scanning for ConfigurationConventionsTest.
  #
  # Split out so the guard itself reads as a list of rules. The precision here
  # is the point: a guard that cries wolf on a log message or a docstring gets
  # switched off, and the protocol it defends then rots quietly.
  module ConfigurationScanner
    # Queue folders that must come from a variable, never a literal.
    QUEUE_FOLDERS = %w[
      _BACK_END _AI_QUEUE _ERROR_QUEUE _SQL_QUEUE _SQL_FAILED _PROGRAM
      _SPOOL_STATE _REJECTED _DELETED _REPROCESS_QUEUE _READY_TO_LEARN
      _MANUAL_PROCESSING _VENDOR_REVIEW _ACTION_NEEDED _BATCH_SPLIT
      _LOW_CONFIDENCE_REVIEW _USER_APPROVAL _GSA_FISCAL _VCFMS_HOLD
      _PENDING_VISION _READY_TO_SPLIT _READY_TO_DELETE
    ].freeze

    def files(globs)
      Array(globs).flat_map { |glob| Dir.glob(Rails.root.join(glob)) }.sort
    end

    def scan(globs, pattern)
      files(globs).flat_map do |path|
        File.readlines(path, chomp: true).filter_map.with_index(1) do |line, number|
          next if comment?(line, path)

          "#{Pathname.new(path).relative_path_from(Rails.root)}:#{number}: #{line.strip}" if line.match?(pattern)
        end
      end
    end

    def comment?(line, path)
      stripped = line.lstrip
      path.end_with?('.py') ? stripped.start_with?('#') : stripped.start_with?('#', '<%#')
    end

    # Line numbers of every line inside a Python triple-quoted block. Docstrings
    # are prose: they are allowed to name the server or describe a folder, and
    # flagging them would push people into writing worse comments.
    def docstring_lines(path)
      return Set.new unless path.end_with?('.py')

      inside = false
      delimiter = nil
      File.readlines(path, chomp: true).each_with_index.with_object(Set.new) do |(line, index), lines|
        remainder = line
        until remainder.empty?
          if inside
            break lines << (index + 1) unless (position = remainder.index(delimiter))

            remainder = remainder[(position + 3)..] || ''
            inside = false
          else
            match = remainder.match(/"""|'''/)
            break unless match

            delimiter = match[0]
            inside = true
            remainder = match.post_match
          end
        end
        lines << (index + 1) if inside
      end
    end

    # A folder name used as a path component, not merely mentioned in a message.
    # "Routed to _BATCH_SPLIT for human review" is log text; "_BATCH_SPLIT" and
    # 'E:\\AIM\\_BACK_END' are paths.
    def path_like?(string, folder)
      string == folder || string.match?(%r{(\A|[\\/])#{Regexp.escape(folder)}(\z|[\\/])})
    end

    # Quoted strings on a line, minus the ones that are plainly variable names.
    def quoted_strings(line)
      line.scan(/'([^']*)'|"([^"]*)"/).flatten.compact.grep_v(/\AAIM_[A-Z0-9_]+\z/)
    end
  end
end

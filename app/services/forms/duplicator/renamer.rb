# frozen_string_literal: true

# app/services/forms/duplicator/renamer.rb

module Forms
  class Duplicator
    # Rewrites a form's identity inside copied source text and file paths:
    # SafetyReport -> SheriffSafetyReportingForm, safety_reports ->
    # sheriff_safety_reporting_forms, "Safety Reporting" -> "Sheriff Safety
    # Reporting", and so on.
    #
    # Renaming works on whole identifiers rather than substrings, because a
    # form's name is often the prefix of something that belongs to someone
    # else: SafetyReportAuthorization is the HCA officer console, not part of
    # the Safety Report form, and a blind gsub would point the copy at a class
    # that does not exist. So:
    #
    # * A CamelCase identifier is renamed only when it is the form class, its
    #   plural, or one of the +companions+ -- the classes the copied files
    #   themselves define (the controller, the PDF generator, section models).
    #   Anything else that merely starts with the form's name is left alone and
    #   reported through #untouched.
    # * A snake_case identifier is renamed where the form's snake name sits in
    #   it as whole underscore-separated words (new_safety_report_path,
    #   @safety_report, safety_reports_controller), unless the identifier is the
    #   snake form of one of those untouched classes.
    # * The form's display name is replaced as a whole phrase.
    class Renamer
      # Underscore counts as a boundary for a class name, so the
      # "SafetyReport_12.pdf" download name follows the form too.
      CAMEL_TOKEN = /(?<![A-Za-z0-9])[A-Z][A-Za-z0-9]*(?![A-Za-z0-9])/
      SNAKE_TOKEN = /\b[a-z_][a-z0-9_]*\b/

      attr_reader :untouched

      def initialize(from_class:, to_class:, from_name:, to_name:, companions: [])
        @from_class = from_class
        @to_class = to_class
        @camel = camel_map(companions)
        @snake = snake_pairs
        @joined = joined_map
        @phrases = phrase_map(from_name, to_name)
        @untouched = Set.new
      end

      # Every identifier-level rename, for display ("SafetyReport → …").
      def mapping
        @camel.merge(@snake).merge(@joined)
      end

      def text(content)
        content = replace_phrases(content)
        excluded = excluded_snake_stems(content)
        content = content.gsub(CAMEL_TOKEN) { |token| rename_camel(token) }
        content = content.gsub(SNAKE_TOKEN) { |token| rename_snake(token, excluded) }
        content.gsub(joined_regex) { |token| @joined.fetch(token, token) }
      end

      def path(relative)
        relative.to_s.split('/').map { |segment| text(segment) }.join('/')
      end

      private

      def camel_map(companions)
        names = [@from_class, *companions].uniq
        names.each_with_object({}) do |name, map|
          renamed = "#{@to_class}#{name.delete_prefix(@from_class)}"
          map[name] = renamed
          map[name.pluralize] = renamed.pluralize
        end.merge(@from_class.pluralize => @to_class.pluralize)
      end

      # Longest first, so safety_reports is tried before safety_report.
      def snake_pairs
        from = @from_class.underscore
        to = @to_class.underscore
        { from.pluralize => to.pluralize, from => to }
      end

      # Data Runner names its DSL and CSV after the table with the underscores
      # squeezed out ("safetyreports"), and capitalises that for the DSL key.
      def joined_map
        from = @from_class.underscore.pluralize.delete('_')
        to = @to_class.underscore.pluralize.delete('_')
        { from => to, from.capitalize => to.capitalize }
      end

      def joined_regex
        @joined_regex ||= /\b(?:#{@joined.keys.map { |k| Regexp.escape(k) }.join('|')})\b/
      end

      # The display name, and the titleized class name the generated PDF
      # prints ("Safety Report"). Word-bounded and longest first, so "Safety
      # Report" never matches inside "Safety Reporting".
      def phrase_map(from_name, to_name)
        pairs = { from_name => to_name, @from_class.titleize => @to_class.titleize }
        pairs.reject { |from, to| from.blank? || from == to }
             .sort_by { |from, _| -from.length }.to_h
      end

      def replace_phrases(content)
        return content if @phrases.empty?

        regex = /\b(?:#{@phrases.keys.map { |k| Regexp.escape(k) }.join('|')})\b/
        content.gsub(regex) { |phrase| @phrases.fetch(phrase, phrase) }
      end

      def rename_camel(token)
        return @camel[token] if @camel.key?(token)

        @untouched << token if token.start_with?(@from_class)
        token
      end

      def rename_snake(token, excluded)
        return token if excluded.any? { |stem| token.match?(word_regex(stem)) }

        token.gsub(snake_regex) { |word| @snake.fetch(word) }
      end

      # One pass over both spellings, so a replacement is never re-matched.
      def snake_regex
        @snake_regex ||= word_regex(@snake.keys)
      end

      # Snake forms of the classes left alone in this text, singular and plural.
      def excluded_snake_stems(content)
        content.scan(CAMEL_TOKEN).uniq.filter_map do |token|
          next if @camel.key?(token) || !token.start_with?(@from_class)

          stem = token.underscore
          [stem.pluralize, stem]
        end.flatten
      end

      # Any of `words` as whole underscore-separated words of an identifier.
      # Only letters and digits count as neighbours, so safety_report matches
      # in new_safety_report_path but not in unsafety_report.
      def word_regex(words)
        @word_regexes ||= {}
        @word_regexes[words] ||= /(?<![a-z0-9])(?:#{Array(words).map { |w| Regexp.escape(w) }.join('|')})(?![a-z0-9])/
      end
    end
  end
end

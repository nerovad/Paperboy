# frozen_string_literal: true

module Paperboy
  module Pdf
    # Breaks text into lines no wider than a limit: at spaces where it can, and
    # inside a word only when the word itself is too long. The block measures
    # a piece of text in points.
    module TextWrap
      module_function

      def lines(text, limit, &width)
        return [text] if width.call(text) <= limit

        out = ['']
        text.split(/(\s+)/).each do |word|
          candidate = out.last + word
          if out.last.empty? || width.call(candidate.rstrip) <= limit
            out[-1] = candidate
          else
            out << word.lstrip
          end
          out.concat(break_word(out.pop, limit, &width)) if width.call(out.last.rstrip) > limit
        end
        out.map(&:rstrip)
      end

      def break_word(word, limit, &width)
        word.each_char.with_object(['']) do |char, pieces|
          pieces << '' if !pieces.last.empty? && width.call(pieces.last + char) > limit
          pieces[-1] += char
        end
      end
    end
  end
end

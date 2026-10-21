# frozen_string_literal: true

module Paperboy
  module Pdf
    # The fonts and see-through graphics states a stamping uses: one object
    # per face and per opacity, made once (by +add+, which stores an object
    # and returns its reference) and named on every stamped page's resources.
    class StampResources
      def initialize(&add)
        @add = add
        @fonts = {}
        @states = {}
      end

      def font_name(box)
        base = Fonts.base_font(box.font, bold: box.bold, italic: box.italic)
        @fonts[base] ||= [:"PbStampF#{@fonts.size + 1}",
                          @add.call({ Type: :Font, Subtype: :Type1, BaseFont: base.to_sym, Encoding: :WinAnsiEncoding })]
        @fonts[base].first
      end

      def state_name(opacity)
        key = Writer.number(opacity)
        @states[key] ||= [:"PbStampGS#{@states.size + 1}", @add.call({ Type: :ExtGState, ca: opacity, CA: opacity })]
        @states[key].first
      end

      # A page's resources with the stamp's added; +deref+ reads an indirect
      # value.
      def merged(resources, &deref)
        resources = resources.dup
        resources[:Font] = with(deref.call(resources[:Font]), @fonts)
        resources[:ExtGState] = with(deref.call(resources[:ExtGState]), @states) if @states.any?
        resources
      end

      private

      def with(existing, made)
        (existing || {}).dup.tap { |dict| made.each_value { |name, object| dict[name] = object } }
      end
    end
  end
end

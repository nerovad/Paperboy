# frozen_string_literal: true

module Aim
  # One PDF going into an Aim::PdfEdit (#181): its objects as pdf-reader read
  # them, and the new number each was given in the file being written (none
  # for the invoice's own PDF, whose numbers stay).
  PdfSource = Struct.new(:objects, :ids) do
    # +value+ with every reference renumbered for the file being written.
    def remap(value)
      case value
      when PDF::Reader::Reference then ids.fetch(value.id) { value }
      when Hash then value.transform_values { |item| remap(item) }
      when Array then value.map { |item| remap(item) }
      when PDF::Reader::Stream then PDF::Reader::Stream.new(remap(value.hash), value.data)
      else value
      end
    end

    # A page's own +key+, or the nearest parent's (Resources, MediaBox,
    # CropBox and Rotate are inherited), as the source numbers it.
    def inherited_value(ref, key)
      node = objects[ref]
      while node
        return node[key] if node.key?(key)

        node = objects.deref(node[:Parent])
      end
      nil
    end
  end
end

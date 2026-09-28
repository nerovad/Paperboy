# frozen_string_literal: true

module Aim
  # Writes PDF objects, as pdf-reader reads them, out as a plain PDF: every
  # object numbered as before, one classic cross-reference table, and the
  # trailer's Root, Info and ID. Aim::PdfStamp's writer.
  class PdfWriter
    def self.number(value) = format('%.3f', value).sub(/\.?0+\z/, '')

    def initialize(trailer)
      @trailer = trailer
    end

    # out: { [id, gen] => object }. Returns the file's bytes.
    def write(out)
      pdf = +"%PDF-1.7\n%\xE2\xE3\xCF\xD3\n".b
      offsets = {}
      out.sort_by { |(id, _), _| id }.each do |(id, gen), object|
        offsets[id] = [pdf.bytesize, gen]
        pdf << "#{id} #{gen} obj\n".b << body_of(object) << "\nendobj\n".b
      end
      size = offsets.keys.max + 1
      xref_at = pdf.bytesize
      pdf << "xref\n0 #{size}\n0000000000 65535 f \n".b
      (1...size).each do |id|
        offset, gen = offsets[id]
        pdf << (offset ? format("%010d %05d n \n", offset, gen) : "0000000000 00000 f \n").b
      end
      trailer = @trailer.slice(:Root, :Info, :ID).merge(Size: size)
      pdf << "trailer\n#{pdf_value(trailer)}\nstartxref\n#{xref_at}\n%%EOF\n".b
    end

    private

    def body_of(object)
      return pdf_value(object).b unless object.is_a?(PDF::Reader::Stream)

      data = object.data.to_s.b
      "#{pdf_value(object.hash.merge(Length: data.bytesize))}\nstream\n".b << data << "\nendstream".b
    end

    def pdf_value(value)
      case value
      when nil then 'null'
      when true, false, Integer then value.to_s
      when Float then self.class.number(value)
      when Symbol then "/#{name(value)}"
      when String then "<#{value.b.unpack1('H*')}>"
      when Array then "[#{value.map { |item| pdf_value(item) }.join(' ')}]"
      when Hash then "<<#{value.map { |key, item| "/#{name(key)} #{pdf_value(item)}" }.join(' ')}>>"
      when PDF::Reader::Reference then "#{value.id} #{value.gen} R"
      else raise PdfStamp::Unstampable, "cannot write a #{value.class}"
      end
    end

    def name(symbol)
      symbol.to_s.b.gsub(%r{[^!-~]|[#()<>\[\]{}/%]}) { |char| format('#%02X', char.ord) }
    end
  end
end

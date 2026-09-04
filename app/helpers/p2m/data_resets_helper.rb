# frozen_string_literal: true

module P2m
  module DataResetsHelper
    OMS_NUMBER = /(?<!\d)(\d{8,9})(?!\d)/

    def p2m_reset_printer_queues(items)
      items.group_by { |item| Pathname.new(item).each_filename.first(2) }.filter_map do |parts, paths|
        next if parts.size < 2

        {
          'printer' => parts.first,
          'queue' => parts.second,
          'files' => paths.map { |path| Pathname.new(path).basename.to_s }.sort
        }
      end
    end

    def p2m_reset_oms_files(items)
      items.group_by do |item|
        item.match(OMS_NUMBER)&.captures&.first || 'Unknown OMS'
      end.sort.to_h
    end
  end
end

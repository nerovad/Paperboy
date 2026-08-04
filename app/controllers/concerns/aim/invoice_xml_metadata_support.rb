# frozen_string_literal: true

module Aim
  module InvoiceXmlMetadataSupport
    extend ActiveSupport::Concern

    private

    def read_xml_metadata(xml_path)
      document = REXML::Document.new(File.read(xml_path))
      fields = {}
      field_data = first_xml_element(document.root, 'FieldData')
      return fields unless field_data

      xml_child_elements_named(field_data, 'Field').each do |field|
        fields[field.attributes['Name'].to_s] = field.text.to_s
      end

      fields
    end

    def write_xml_metadata(xml_path, metadata_params)
      document = REXML::Document.new(File.read(xml_path))
      field_data = first_xml_element(document.root, 'FieldData')

      unless field_data
        parent = first_xml_element(document.root, 'Doc') || document.root
        field_data = parent.add_element(xml_child_name(parent, 'FieldData'))
      end

      fields_by_name = {}
      xml_child_elements_named(field_data, 'Field').each do |field|
        fields_by_name[field.attributes['Name'].to_s] = field
      end

      metadata_params.each do |key, value|
        field = fields_by_name[key.to_s] || field_data.add_element(xml_child_name(field_data, 'Field'), { 'Name' => key.to_s })
        field.text = value.to_s
      end

      formatter = REXML::Formatters::Pretty.new(2)
      formatter.compact = true
      output = +''
      formatter.write(document, output)
      File.write(xml_path, output)
    end

    def first_xml_element(element, local_name)
      return unless element
      return element if xml_local_name(element) == local_name

      element.elements.each do |child|
        match = first_xml_element(child, local_name)
        return match if match
      end

      nil
    end

    def xml_child_elements_named(element, local_name)
      element.elements.select { |child| xml_local_name(child) == local_name }
    end

    def xml_local_name(element)
      element.name.to_s.split(':').last
    end

    def xml_child_name(parent, local_name)
      prefix = parent.name.to_s.include?(':') ? parent.name.to_s.split(':').first : nil
      prefix ? "#{prefix}:#{local_name}" : local_name
    end
  end
end

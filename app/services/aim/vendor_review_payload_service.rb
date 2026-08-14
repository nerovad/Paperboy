# frozen_string_literal: true

module Aim
  class VendorReviewPayloadService
    def self.sql_ready_payload(invoice_id:, pdf_file:, metadata:, extracted_name:, normalized_name:)
      new(invoice_id, pdf_file, metadata, extracted_name, normalized_name).sql_ready_payload
    end

    def initialize(invoice_id, pdf_file, metadata, extracted_name, normalized_name)
      @invoice_id = invoice_id
      @pdf_file = pdf_file
      @metadata = metadata
      @extracted_name = extracted_name
      @normalized_name = normalized_name
    end

    def sql_ready_payload
      {
        'FileName' => @pdf_file || "#{@invoice_id}.pdf",
        'Submitter' => metadata_value('Submitter', 'submitter', 'Submitted by'),
        'BU' => metadata_value('BU', 'bu', 'BudgetUnit', 'Budget Unit Number'),
        'VendorName' => @normalized_name,
        'InvoiceNumber' => metadata_value('InvoiceNumber', 'invoice_number', 'Invoice Number'),
        'InvoiceTotal' => metadata_value('InvoiceTotal', 'invoice_total', 'Invoice Total'),
        'InvoiceDate' => metadata_value('InvoiceDate', 'invoice_date', 'Invoice Date'),
        'OrderNumber' => metadata_value('OrderNumber', 'order_number', 'Order Number'),
        'CustomerNumber' => metadata_value('CustomerNumber', 'customer_number', 'Customer Number'),
        'Subtotal' => metadata_value('Subtotal', 'subtotal'),
        'SalesTax' => metadata_value('SalesTax', 'sales_tax', 'Sales Tax'),
        'ExtractedMetadata' => JSON.generate(extracted_metadata_payload),
        'Status' => 'SUCCESS',
        'ErrorMessage' => nil,
        'ProcessedTimestamp' => Time.zone.now.strftime('%Y-%m-%d %H:%M:%S'),
        'InvoiceConcatID' => @invoice_id
      }
    end

    private

    def extracted_metadata_payload
      raw_metadata = @metadata['ExtractedMetadata']
      extracted_metadata = parsed_extracted_metadata(raw_metadata)
      extracted_metadata['extracted_vendor_name'] = @extracted_name
      extracted_metadata['vendor_name'] = @normalized_name
      extracted_metadata
    end

    def parsed_extracted_metadata(raw_metadata)
      return raw_metadata.deep_dup if raw_metadata.is_a?(Hash)
      return JSON.parse(raw_metadata) if raw_metadata.present?

      @metadata.deep_dup
    rescue JSON::ParserError, TypeError
      @metadata.deep_dup
    end

    def metadata_value(*keys)
      keys.each do |key|
        value = @metadata[key]
        return value if value.present?
      end

      nil
    end
  end
end

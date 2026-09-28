# frozen_string_literal: true

module P2m
  module InlineFileResponse
    extend ActiveSupport::Concern

    private

    def send_inline_file(file)
      send_data File.binread(file),
                filename: file.basename.to_s,
                type: Rack::Mime.mime_type(file.extname, 'application/octet-stream'),
                disposition: 'inline'
    end
  end
end

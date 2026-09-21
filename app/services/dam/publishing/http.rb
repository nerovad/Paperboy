# frozen_string_literal: true

module Dam
  module Publishing
    # The one place this app opens a connection to a publishing service.
    #
    # Thin on purpose: every adapter needs the same four things — a JSON POST,
    # a form POST, a multipart upload and a raw byte upload — and sharing them
    # is what keeps timeouts, TLS and error shape identical whichever service
    # is being talked to. Adapters take one of these in their constructor, so
    # a test hands them a fake instead of reaching the internet.
    class Http
      OPEN_TIMEOUT = 15
      # Long: this is a video upload, and a two-gigabyte master over a county
      # uplink is not a fast request.
      READ_TIMEOUT = 600

      Response = Struct.new(:code, :body, :headers, keyword_init: true) do
        def success? = code.to_i.between?(200, 299)

        def json
          @json ||= JSON.parse(body.to_s)
        rescue JSON::ParserError
          @json = {}
        end

        # The most useful sentence the far end gave us. Every one of these
        # APIs reports an error differently, and a publication that says
        # "quota exceeded" is worth ten that say 403.
        def error_message
          payload = json
          payload.dig('error', 'message') || payload['error_description'] ||
            payload.dig('error', 'error_user_msg') || payload.dig('error', 'message_type') ||
            payload['message'] || payload['developer_message'] ||
            payload.dig('error', 'code')&.to_s || body.to_s.truncate(300)
        end
      end

      def get(url, headers: {}) = send_request(Net::HTTP::Get, url, headers: headers)

      def delete(url, headers: {}) = send_request(Net::HTTP::Delete, url, headers: headers)

      def post_form(url, fields, headers: {})
        send_request(Net::HTTP::Post, url, headers: headers) { |request| request.set_form_data(fields) }
      end

      def post_json(url, payload, headers: {})
        json_request(Net::HTTP::Post, url, payload, headers: headers)
      end

      def json_request(verb, url, payload, headers: {})
        send_request(verb, url, headers: headers.merge('Content-Type' => 'application/json')) do |request|
          request.body = payload.to_json
        end
      end

      # A file as one part of a form, streamed rather than read into memory.
      def post_multipart(url, file:, file_field: 'file', filename: nil, content_type: nil, fields: {}, headers: {},
                         verb: Net::HTTP::Post)
        File.open(file, 'rb') do |io|
          parts = fields.map { |name, value| [name.to_s, value.to_s] }
          parts << [file_field.to_s, io, { filename: filename || File.basename(file),
                                           content_type: content_type || 'application/octet-stream' }]
          send_request(verb, url, headers: headers) { |request| request.set_form(parts, 'multipart/form-data') }
        end
      end

      # Raw bytes as the whole body — how every resumable upload session of
      # these five wants its file. A range uploads one slice without reading
      # the rest, which is what makes a multi-gigabyte master possible at all.
      def send_file(verb, url, file, headers: {}, offset: 0, length: nil)
        size = File.size(file)
        length ||= size - offset
        File.open(file, 'rb') do |io|
          io.seek(offset)
          send_request(verb, url, headers: headers.merge('Content-Length' => length.to_s)) do |request|
            request.body_stream = ChunkIo.new(io, length)
          end
        end
      end

      private

      def send_request(verb, url, headers: {})
        uri = URI.parse(url.to_s)
        raise Error, "Not a http address: #{url}" unless uri.is_a?(URI::HTTP)

        request = verb.new(uri)
        headers.each { |name, value| request[name.to_s] = value.to_s }
        yield request if block_given?
        run(uri, request)
      end

      def run(uri, request)
        response = http_for(uri).request(request)
        Response.new(code: response.code.to_i, body: response.body, headers: response.to_hash)
      rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, SocketError => e
        # A network failure and a refusal read the same way on the publication
        # page, and neither is a bug in this app worth a backtrace.
        raise DeliveryFailed, "#{uri.host} could not be reached: #{e.class} #{e.message}"
      end

      def http_for(uri)
        Net::HTTP.new(uri.host, uri.port).tap do |http|
          http.use_ssl = uri.scheme == 'https'
          http.open_timeout = OPEN_TIMEOUT
          http.read_timeout = READ_TIMEOUT
        end
      end

      # Reads at most +length+ bytes from where an IO already sits, so one
      # slice of a large file can be a request body on its own.
      class ChunkIo
        def initialize(io, length)
          @io = io
          @remaining = length
        end

        def read(bytes = nil, outbuf = nil)
          return @io.read(0, outbuf) if @remaining <= 0

          wanted = bytes.nil? ? @remaining : [bytes, @remaining].min
          chunk = @io.read(wanted, outbuf)
          @remaining -= chunk.bytesize if chunk
          chunk
        end

        def size = @remaining
      end
    end
  end
end

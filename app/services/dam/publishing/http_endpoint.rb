# frozen_string_literal: true

module Dam
  module Publishing
    # Anywhere else: a URL typed into the target form, with headers to match.
    #
    # This is the reason publishing is not a list of five services. A county
    # website, an intranet media store, a partner's ingest endpoint and a
    # webhook are all the same shape — send this file, or a description of it,
    # to this address with this token — and none of them is worth an adapter
    # of its own.
    #
    # Two styles, because both are asked for: the file itself as a multipart
    # form, or a JSON description carrying a link the far end fetches.
    class HttpEndpoint < Base
      class << self
        def label = 'Custom HTTP endpoint'

        def media_types = Dam::Asset::MEDIA_TYPES

        def oauth? = false

        def account_prompt
          { label: 'Reference', hint: 'Anything the endpoint needs to identify this target — an account, ' \
                                      'a folder, a feed. Sent as "target".', required: false }
        end
      end

      def deliver
        target.body_style == 'json' ? send_description : send_file
      end

      private

      def send_file
        with_source_file do |path, size|
          log("Sending #{ActiveSupport::NumberHelper.number_to_human_size(size)} to #{target.endpoint_url}")
          response = expect!(http.post_multipart(target.endpoint_url, file: path, file_field: target.file_field,
                                                                      filename: filename, content_type: content_type, fields: fields,
                                                                      headers: headers, verb: verb),
                             'upload')
          identify(response)
        end
      end

      def send_description
        log("Describing the asset to #{target.endpoint_url}")
        payload = fields.merge('file_url' => public_file_url, 'filename' => filename,
                               'content_type' => content_type, 'byte_size' => asset.byte_size)
        identify(expect!(http.json_request(verb, target.endpoint_url, payload, headers: headers), 'request'))
      end

      def verb = target.http_method == 'PUT' ? Net::HTTP::Put : Net::HTTP::Post

      def headers = target.header_pairs.merge('Accept' => 'application/json')

      def fields
        {
          'title' => publication.title.to_s,
          'description' => description,
          'tags' => publication.tag_list.join(','),
          'privacy' => privacy.to_s,
          'media_type' => asset.media_type,
          'asset_id' => asset.id.to_s,
          'target' => target.account_ref.to_s
        }
      end

      # Whatever the endpoint says it made of it. Anything that answers with
      # an id or a link gets one recorded; anything that just says 200 leaves
      # the publication with the status and nothing else, which is honest.
      def identify(response)
        body = response.json
        Result.new(external_id: body['id'] || body['identifier'],
                   external_url: body['url'] || body['link'] || Array(response.headers['location']).first,
                   response_code: response.code)
      end
    end
  end
end

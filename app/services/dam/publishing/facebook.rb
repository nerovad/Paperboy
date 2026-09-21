# frozen_string_literal: true

module Dam
  module Publishing
    # A Facebook Page, through the Graph API.
    #
    # Posting as a page needs a page token rather than the one consent handed
    # back, so the first request here trades the user token for the page's.
    # That is also the check that whoever connected the target actually
    # administers the page it names.
    class Facebook < Base
      GRAPH = 'https://graph.facebook.com/v21.0'
      # Video goes to a host of its own; posting a large file to the ordinary
      # graph host is what Meta's docs quietly mean by "may time out".
      VIDEO_GRAPH = 'https://graph-video.facebook.com/v21.0'

      class << self
        def label = 'Facebook'

        def media_types = %w[video image]

        def account_prompt
          { label: 'Page ID', hint: 'The numeric ID of the Facebook Page this target posts to. ' \
                                    'Found under Page settings, About.', required: true }
        end
      end

      def deliver
        page_token = page_access_token
        asset.media_type == 'video' ? post_video(page_token) : post_photo(page_token)
      end

      private

      def page_access_token
        response = expect!(http.get("#{GRAPH}/#{account_ref!}?fields=access_token", headers: bearer), 'page token')
        token = response.json['access_token']
        raise DeliveryFailed.new("The connected account does not administer page #{account_ref!}", response_code: response.code) if token.blank?

        token
      end

      def post_video(page_token)
        with_source_file do |path, size|
          log("Sending #{ActiveSupport::NumberHelper.number_to_human_size(size)} to page #{account_ref!}")
          response = expect!(http.post_multipart("#{VIDEO_GRAPH}/#{account_ref!}/videos", file: path,
                                                                                         file_field: 'source', filename: filename, content_type: content_type,
                                                                                         fields: { 'title' => publication.title.to_s, 'description' => description },
                                                                                         headers: page_bearer(page_token)),
                             'video post')
          identify(response)
        end
      end

      def post_photo(page_token)
        with_source_file do |path, _size|
          response = expect!(http.post_multipart("#{GRAPH}/#{account_ref!}/photos", file: path,
                                                                                   file_field: 'source', filename: filename, content_type: content_type,
                                                                                   fields: { 'caption' => caption, 'published' => 'true' },
                                                                                   headers: page_bearer(page_token)),
                             'photo post')
          identify(response)
        end
      end

      # A photo's caption is the only text it carries, so the title leads and
      # the description follows it rather than being dropped.
      def caption
        [publication.title, description.presence].compact_blank.join("\n\n")
      end

      def page_bearer(page_token) = { 'Authorization' => "Bearer #{page_token}", 'Accept' => 'application/json' }

      def identify(response)
        body = response.json
        id = body['post_id'].presence || body['id']
        log("Facebook posted #{id}")
        Result.new(external_id: id, external_url: "https://www.facebook.com/#{id}", response_code: response.code)
      end
    end
  end
end

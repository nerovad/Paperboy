# frozen_string_literal: true

module Dam
  module Publishing
    # YouTube, through the Data API's resumable upload.
    #
    # Two requests: one that describes the video and opens an upload session,
    # one that sends the file to the address the first came back with. The
    # bytes are streamed from disk, because a master is a master.
    class Youtube < Base
      START_URL = 'https://www.googleapis.com/upload/youtube/v3/videos'
      PARTS = 'snippet,status'

      # 22 is "People & Blogs" — YouTube requires a category and this is the
      # one that fits anything. A target may name another.
      DEFAULT_CATEGORY = '22'

      class << self
        def label = 'YouTube'

        def media_types = %w[video]

        def account_prompt
          { label: 'Category ID', hint: 'YouTube numeric category, 22 (People & Blogs) if left blank. ' \
                                        'The channel is whichever one was connected.', required: false }
        end

        def privacy_options
          { 'unlisted' => 'Unlisted — anyone with the link', 'private' => 'Private — only the channel',
            'public' => 'Public — listed and searchable' }
        end
      end

      def deliver
        with_source_file do |path, size|
          upload_url = open_session(size)
          log("Upload session opened, sending #{ActiveSupport::NumberHelper.number_to_human_size(size)}")
          response = expect!(http.send_file(Net::HTTP::Put, upload_url, path,
                                            headers: { 'Content-Type' => content_type }), 'upload')
          video_id = response.json['id']
          log("YouTube accepted the video as #{video_id}")
          Result.new(external_id: video_id, external_url: "https://www.youtube.com/watch?v=#{video_id}",
                     response_code: response.code)
        end
      end

      private

      def open_session(size)
        response = expect!(http.json_request(Net::HTTP::Post, "#{START_URL}?uploadType=resumable&part=#{PARTS}",
                                             metadata,
                                             headers: bearer('X-Upload-Content-Length' => size.to_s,
                                                             'X-Upload-Content-Type' => content_type)),
                           'upload session')
        location = Array(response.headers['location']).first
        raise DeliveryFailed.new('YouTube opened no upload session', response_code: response.code) if location.blank?

        location
      end

      def metadata
        {
          snippet: { title: publication.title.to_s.truncate(100), description: description.truncate(5000),
                     tags: publication.tag_list, categoryId: target.account_ref.presence || DEFAULT_CATEGORY },
          # selfDeclaredMadeForKids has been required since COPPA; leaving it
          # out makes the upload fail rather than default.
          status: { privacyStatus: privacy, selfDeclaredMadeForKids: false }
        }
      end
    end
  end
end

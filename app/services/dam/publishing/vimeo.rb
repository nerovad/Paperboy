# frozen_string_literal: true

module Dam
  module Publishing
    # Vimeo, through its tus upload.
    #
    # Vimeo makes the video record first and hands back a tus endpoint; the
    # file then goes up as the body of a PATCH. Its tokens do not expire, so a
    # target here stays connected until somebody revokes it at Vimeo's end.
    class Vimeo < Base
      CREATE_URL = 'https://api.vimeo.com/me/videos'
      API_VERSION = 'application/vnd.vimeo.*+json;version=3.4'
      TUS_VERSION = '1.0.0'

      class << self
        def label = 'Vimeo'

        def media_types = %w[video]

        def token_lifetime = :permanent

        def privacy_options
          { 'unlisted' => 'Unlisted — anyone with the link', 'nobody' => 'Private — only me',
            'anybody' => 'Public — anyone on Vimeo' }
        end
      end

      def deliver
        with_source_file do |path, size|
          video = create_video(size)
          log("Vimeo made #{video['uri']}, sending #{ActiveSupport::NumberHelper.number_to_human_size(size)}")
          upload(video.dig('upload', 'upload_link'), path)
          Result.new(external_id: video['uri'].to_s.split('/').last, external_url: video['link'])
        end
      end

      private

      def create_video(size)
        payload = {
          upload: { approach: 'tus', size: size },
          name: publication.title.to_s.truncate(128),
          description: description,
          privacy: { view: privacy }
        }
        response = expect!(http.post_json(CREATE_URL, payload, headers: bearer('Accept' => API_VERSION)), 'new video')
        video = response.json
        raise DeliveryFailed.new('Vimeo returned no upload link', response_code: response.code) if video.dig('upload', 'upload_link').blank?

        video
      end

      def upload(upload_link, path)
        response = expect!(http.send_file(Net::HTTP::Patch, upload_link, path,
                                          headers: { 'Tus-Resumable' => TUS_VERSION, 'Upload-Offset' => '0',
                                                     'Content-Type' => 'application/offset+octet-stream' }),
                           'upload')
        log("Vimeo has the file (#{Array(response.headers['upload-offset']).first} bytes)")
        response
      end
    end
  end
end

# frozen_string_literal: true

module Dam
  module Publishing
    # TikTok, through the Content Posting API.
    #
    # An init call returns a one-time upload address, the file goes up in
    # chunks TikTok dictates the size of, and the post itself appears some
    # minutes later — so what comes back is a publish id rather than a link.
    #
    # Note the privacy default: until an app has passed TikTok's audit it may
    # only post privately, and a public post from an unaudited app is refused
    # rather than quietly downgraded.
    class Tiktok < Base
      INIT_URL = 'https://open.tiktokapis.com/v2/post/publish/video/init/'
      STATUS_URL = 'https://open.tiktokapis.com/v2/post/publish/status/fetch/'

      # TikTok's own limits: a whole file in one piece up to 64MB, otherwise
      # chunks of at least 5MB, and no more than 1000 of them.
      SINGLE_CHUNK_LIMIT = 64 * 1024 * 1024
      CHUNK_SIZE = 32 * 1024 * 1024

      class << self
        def label = 'TikTok'

        def media_types = %w[video]

        def privacy_options
          { 'SELF_ONLY' => 'Private — only me (required until the app is audited)',
            'MUTUAL_FOLLOW_FRIENDS' => 'Friends', 'FOLLOWER_OF_CREATOR' => 'Followers',
            'PUBLIC_TO_EVERYONE' => 'Public' }
        end
      end

      def deliver
        with_source_file do |path, size|
          chunk_size, chunks = chunking_for(size)
          publish_id, upload_url = init(size, chunk_size, chunks)
          log("TikTok is expecting #{chunks} #{'chunk'.pluralize(chunks)}")
          send_chunks(upload_url, path, size, chunk_size, chunks)
          Result.new(external_id: publish_id, external_url: posted_url(publish_id))
        end
      end

      private

      # A file that fits goes in one piece. Anything larger is cut into equal
      # chunks, with the remainder riding along on the last one — TikTok
      # refuses a final chunk smaller than the minimum, so it cannot simply be
      # a short one of its own.
      def chunking_for(size)
        return [size, 1] if size <= SINGLE_CHUNK_LIMIT

        [CHUNK_SIZE, size / CHUNK_SIZE]
      end

      def init(size, chunk_size, chunks)
        payload = {
          post_info: { title: publication.title.to_s.truncate(2200), privacy_level: privacy,
                       disable_duet: false, disable_comment: false, disable_stitch: false },
          source_info: { source: 'FILE_UPLOAD', video_size: size, chunk_size: chunk_size,
                         total_chunk_count: chunks }
        }
        response = expect!(http.post_json(INIT_URL, payload, headers: bearer), 'upload request')
        data = response.json['data'].to_h
        raise DeliveryFailed.new("TikTok opened no upload: #{response.error_message}", response_code: response.code) if data['upload_url'].blank?

        [data['publish_id'], data['upload_url']]
      end

      def send_chunks(upload_url, path, size, chunk_size, chunks)
        chunks.times do |index|
          offset = index * chunk_size
          length = index == chunks - 1 ? size - offset : chunk_size
          headers = { 'Content-Type' => content_type,
                      'Content-Range' => "bytes #{offset}-#{offset + length - 1}/#{size}" }
          expect!(http.send_file(Net::HTTP::Put, upload_url, path, headers: headers, offset: offset, length: length),
                  "upload of chunk #{index + 1}")
          log("Sent chunk #{index + 1} of #{chunks}")
        end
      end

      # TikTok processes after the upload, so the post may not exist yet. One
      # look is enough: the publish id is what the status screen tracks, and a
      # link is a bonus rather than the record.
      def posted_url(publish_id)
        response = http.post_json(STATUS_URL, { publish_id: publish_id }, headers: bearer)
        return nil unless response.success?

        data = response.json['data'].to_h
        log("TikTok says #{data['status']}")
        Array(data['publicaly_available_post_id']).first&.then { |id| "https://www.tiktok.com/video/#{id}" }
      rescue Error
        nil
      end
    end
  end
end

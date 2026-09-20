# frozen_string_literal: true

module Dam
  module Publishing
    # An Instagram professional account, through the Graph API.
    #
    # Instagram will not be handed bytes. It is given a link and fetches the
    # file itself, which is why this is the one provider that needs Paperboy
    # to be reachable from outside the county network — see #public_file_url,
    # and PAPERBOY_PUBLIC_BASE_URL.
    #
    # Publishing is two steps with a wait in the middle: a container is
    # created, Instagram downloads and transcodes it, and only a finished
    # container can be published.
    class Instagram < Base
      GRAPH = 'https://graph.facebook.com/v21.0'
      POLL_EVERY = 5.seconds
      POLL_FOR = 10.minutes

      class << self
        def label = 'Instagram'

        def media_types = %w[video image]

        def needs_public_url? = true

        def account_prompt
          { label: 'Instagram account ID', hint: 'The professional (business or creator) account ID, ' \
                                                 'as shown by the linked Facebook Page.', required: true }
        end
      end

      def deliver
        container = create_container
        log("Container #{container} created; waiting for Instagram to fetch the file")
        await_container(container) if asset.media_type == 'video'
        publish(container)
      end

      private

      def create_container
        fields = { 'caption' => caption }
        if asset.media_type == 'video'
          fields['video_url'] = public_file_url
          fields['media_type'] = 'REELS'
        else
          fields['image_url'] = public_file_url
        end

        response = expect!(http.post_form("#{GRAPH}/#{account_ref!}/media", fields, headers: bearer), 'container')
        id = response.json['id']
        raise DeliveryFailed.new('Instagram made no container', response_code: response.code) if id.blank?

        id
      end

      # Instagram reports a container as IN_PROGRESS while it downloads and
      # transcodes. Publishing one that is not FINISHED fails, so this waits
      # rather than optimistically posting.
      def await_container(container)
        deadline = POLL_FOR.from_now
        loop do
          response = expect!(http.get("#{GRAPH}/#{container}?fields=status_code,status", headers: bearer), 'container status')
          state = response.json['status_code']
          return if state == 'FINISHED'
          raise DeliveryFailed.new("Instagram could not use the file: #{response.json['status']}", response_code: response.code) if state == 'ERROR'
          raise DeliveryFailed, 'Instagram was still fetching the file after ten minutes' if Time.current > deadline

          sleep POLL_EVERY
        end
      end

      def publish(container)
        response = expect!(http.post_form("#{GRAPH}/#{account_ref!}/media_publish", { 'creation_id' => container },
                                          headers: bearer), 'publish')
        id = response.json['id']
        log("Instagram published #{id}")
        Result.new(external_id: id, external_url: permalink(id), response_code: response.code)
      end

      # A permalink is a second request, and not worth failing the publish
      # over: the post is already up by this point.
      def permalink(id)
        response = http.get("#{GRAPH}/#{id}?fields=permalink", headers: bearer)
        response.success? ? response.json['permalink'] : nil
      rescue Error
        nil
      end

      def caption
        [publication.title, description.presence, publication.tag_list.map { |tag| "##{tag.delete(' ')}" }.join(' ').presence]
          .compact_blank.join("\n\n")
      end
    end
  end
end

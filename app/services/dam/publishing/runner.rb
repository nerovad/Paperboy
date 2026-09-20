# frozen_string_literal: true

module Dam
  module Publishing
    # One publication, carried out.
    #
    # Everything that decides how a row ends up is here rather than in the
    # adapters: they either come back with a Result or raise, and this turns
    # that into a status, a log and a line on the Jobs feed. A publish that
    # fails is a finished row with a reason on it, never an exception escaping
    # into the queue's own retry logic — the retry button is on the screen,
    # where somebody can read the reason first.
    class Runner
      def initialize(publication, http: Http.new)
        @publication = publication
        @target = publication.publish_target
        @http = http
      end

      def call
        refusal = @target.refusal_reason(@publication.asset)
        return fail_with("#{@target.label} cannot take this asset: #{refusal}") if refusal

        start
        finish(deliver)
      rescue Publishing::Error => e
        fail_with(e.message, response_code: e.try(:response_code))
      rescue StandardError => e
        # Anything unforeseen is still this publication's failure, not the
        # worker's: the row has to say what happened.
        fail_with("#{e.class}: #{e.message}")
      end

      private

      attr_reader :publication, :target

      def start
        publication.start!
        publication.append_log("Publishing #{publication.asset_title} to #{target.label} (#{target.provider_label})")
        job&.update!(status: 'running', started_at: Time.current)
        job&.append_log("Publishing to #{target.label}")
        job&.save
      end

      def deliver
        token = target.oauth? ? Oauth.new(target, http: @http).fresh_access_token! : nil
        adapter = target.adapter_class.new(publication, http: @http, access_token: token)
        adapter.deliver
      end

      def finish(result)
        publication.append_log('Done')
        publication.succeed!(external_id: result&.external_id, external_url: result&.external_url,
                             response_code: result&.response_code)
        job&.append_log(['Published', result&.external_url].compact_blank.join(': '))
        job&.update(status: 'succeeded', processed_items: 1, finished_at: Time.current, log: job.log)
        publication
      end

      def fail_with(message, response_code: nil)
        publication.append_log("Failed: #{message}")
        publication.fail!(message, response_code: response_code)
        job&.append_log("Failed: #{message}")
        job&.update(status: 'failed', error: message.to_s.truncate(2000), finished_at: Time.current, log: job.log)
        publication
      end

      # The Jobs feed entry, when the publish was raised through one. A
      # publication run straight from the console has none, and works anyway.
      def job
        return @job if defined?(@job)

        @job = publication.job_id.present? ? Dam::Job.find_by(id: publication.job_id) : nil
      end
    end
  end
end

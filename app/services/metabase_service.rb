class MetabaseService
  class MetabaseError < StandardError; end

  def initialize
    @site_url = ENV.fetch("METABASE_SITE_URL")
    @secret_key = ENV.fetch("METABASE_SECRET_KEY")
  end

  def embed_url(dashboard_id, params: {})
    payload = {
      resource: { dashboard: dashboard_id },
      params: params,
      exp: 10.minutes.from_now.to_i
    }

    token = JWT.encode(payload, @secret_key)
    "#{@site_url}/embed/dashboard/#{token}#bordered=false&titled=true"
  end
end

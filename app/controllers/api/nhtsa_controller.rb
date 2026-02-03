class Api::NhtsaController < ApplicationController
  NHTSA_BASE = "https://vpic.nhtsa.dot.gov/api/vehicles".freeze

  def makes
    uri = URI("#{NHTSA_BASE}/GetMakesForVehicleType/car?format=json")
    data = fetch_nhtsa(uri)
    render json: data["Results"]
  rescue => e
    Rails.logger.error("NHTSA makes fetch failed: #{e.message}")
    render json: { error: e.message }, status: :service_unavailable
  end

  def models
    make = params.require(:make)
    year = params.require(:year)

    uri = URI("#{NHTSA_BASE}/GetModelsForMakeYear/make/#{ERB::Util.url_encode(make)}/modelyear/#{ERB::Util.url_encode(year)}?format=json")
    data = fetch_nhtsa(uri)
    render json: data["Results"]
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  rescue => e
    Rails.logger.error("NHTSA models fetch failed: #{e.message}")
    render json: { error: e.message }, status: :service_unavailable
  end

  private

  def fetch_nhtsa(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    response = http.request(Net::HTTP::Get.new(uri))
    raise "NHTSA returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end

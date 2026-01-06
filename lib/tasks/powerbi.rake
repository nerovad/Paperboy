namespace :powerbi do
  desc "Get Power BI workspace ID for debugging"
  task get_workspace_id: :environment do
    require 'net/http'
    require 'uri'
    require 'json'

    puts "Fetching Power BI workspaces..."
    puts "Using Government Cloud endpoints"
    puts

    # Get Azure AD access token
    authority_url = ENV['POWERBI_AUTHORITY_URL'] || 'https://login.microsoftonline.us'
    tenant_id = ENV['POWERBI_TENANT_ID']

    if tenant_id.blank?
      puts "ERROR: POWERBI_TENANT_ID not set in .env"
      exit 1
    end

    token_uri = URI.parse("#{authority_url}/#{tenant_id}/oauth2/v2.0/token")

    http = Net::HTTP.new(token_uri.host, token_uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(token_uri.request_uri)
    request.set_form_data(
      'grant_type' => 'client_credentials',
      'client_id' => ENV['POWERBI_CLIENT_ID'],
      'client_secret' => ENV['POWERBI_CLIENT_SECRET'],
      'scope' => ENV['POWERBI_SCOPE']
    )

    begin
      response = http.request(request)
      token_data = JSON.parse(response.body)

      if token_data['error']
        puts "ERROR getting access token:"
        puts "  #{token_data['error']}: #{token_data['error_description']}"
        exit 1
      end

      access_token = token_data['access_token']
      puts "✓ Successfully obtained access token"
      puts

      # Get workspaces
      api_url = ENV['POWERBI_API_URL'] || 'https://api.powerbigov.us'
      workspaces_uri = URI.parse("#{api_url}/v1.0/myorg/groups")

      http = Net::HTTP.new(workspaces_uri.host, workspaces_uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(workspaces_uri.request_uri)
      request['Authorization'] = "Bearer #{access_token}"

      response = http.request(request)
      workspaces_data = JSON.parse(response.body)

      if workspaces_data['error']
        puts "ERROR getting workspaces:"
        puts "  #{workspaces_data['error']['code']}: #{workspaces_data['error']['message']}"
        exit 1
      end

      puts "Available workspaces:"
      puts "=" * 80

      workspaces_data['value'].each do |workspace|
        puts "Name: #{workspace['name']}"
        puts "ID:   #{workspace['id']}"
        puts "Type: #{workspace['type'] || 'Workspace'}"
        puts "-" * 80
      end

      puts
      puts "To update your Critical Information Reporting form template, run:"
      puts "bin/rails runner \"FormTemplate.find(17).update(powerbi_workspace_id: 'YOUR_WORKSPACE_ID', powerbi_report_id: 'ea1b274a-5804-4b14-9c77-eb4c814df320')\""

    rescue => e
      puts "ERROR: #{e.message}"
      puts e.backtrace.first(5)
      exit 1
    end
  end

  desc "Test Power BI embed token generation"
  task test_embed_token: :environment do
    form = FormTemplate.find_by(name: "Critical Information Reporting")

    if form.blank?
      puts "ERROR: Critical Information Reporting form not found"
      exit 1
    end

    if !form.has_dashboard?
      puts "ERROR: Form doesn't have Power BI configuration yet"
      puts "Run: rake powerbi:get_workspace_id to get your workspace ID first"
      exit 1
    end

    puts "Testing embed token generation for #{form.name}..."
    puts "Workspace ID: #{form.powerbi_workspace_id}"
    puts "Report ID:    #{form.powerbi_report_id}"
    puts

    service = PowerBiService.new({})
    token_data = service.generate_embed_token(
      form.powerbi_workspace_id,
      form.powerbi_report_id
    )

    puts "✓ Successfully generated embed token"
    puts "Token: #{token_data[:token][0..50]}..."
    puts "Expires: #{token_data[:expiration]}"
  end
end

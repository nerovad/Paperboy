# Power BI Authentication Integration Guide

## Current State
The dashboard feature is currently using placeholder tokens. This allows the UI framework to be built and tested while authentication is configured separately.

## Required Steps for Production Auth

### 1. Azure AD App Registration
1. Go to [Azure Portal](https://portal.azure.com) > Azure Active Directory > App Registrations
2. Create new app registration named "Paperboy Power BI Integration"
3. Note the **Application (client) ID**
4. Go to "Certificates & secrets" and create a new client secret
5. Note the **client secret value** (only shown once!)
6. Add API permissions:
   - Microsoft Power BI Service > Delegated > Report.Read.All
   - Microsoft Power BI Service > Application > Report.ReadWrite.All
   - Microsoft Power BI Service > Application > Dataset.Read.All
7. Grant admin consent for the permissions

### 2. Power BI Service Principal Setup
1. Go to [Power BI Admin Portal](https://app.powerbi.com/admin-portal) > Tenant Settings
2. Enable "Allow service principals to use Power BI APIs"
3. Create a security group in Azure AD that contains your app registration
4. Add this security group to the allowed list in Power BI tenant settings
5. For each workspace containing dashboards:
   - Go to Workspace settings > Access
   - Add the app registration with "Member" or "Admin" role

### 3. Update Environment Variables

Add to `.env`:

```bash
# Power BI Configuration
POWERBI_CLIENT_ID=your_application_client_id_here
POWERBI_CLIENT_SECRET=your_client_secret_here
POWERBI_TENANT_ID=your_azure_tenant_id_here
POWERBI_AUTHORITY_URL=https://login.microsoftonline.com/your_tenant_id
POWERBI_SCOPE=https://analysis.windows.net/powerbi/api/.default
```

**For Government Cloud** (Ventura County may use this):
```bash
POWERBI_SCOPE=https://analysis.usgovcloudapi.net/powerbi/api/.default
```

### 4. Update PowerBiService

Replace the placeholder methods in `/app/services/power_bi_service.rb` with actual implementation:

```ruby
class PowerBiService
  def initialize(user_session)
    @user_session = user_session
  end

  def generate_embed_token(workspace_id, report_id)
    # Get Azure AD access token
    access_token = get_azure_ad_token

    # Call Power BI REST API to generate embed token
    embed_token_response = request_embed_token(access_token, workspace_id, report_id)

    {
      token: embed_token_response['token'],
      expiration: embed_token_response['expiration']
    }
  end

  private

  def get_azure_ad_token
    require 'net/http'
    require 'uri'
    require 'json'

    uri = URI.parse("#{ENV['POWERBI_AUTHORITY_URL']}/oauth2/v2.0/token")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data(
      'grant_type' => 'client_credentials',
      'client_id' => ENV['POWERBI_CLIENT_ID'],
      'client_secret' => ENV['POWERBI_CLIENT_SECRET'],
      'scope' => ENV['POWERBI_SCOPE']
    )

    response = http.request(request)
    token_data = JSON.parse(response.body)

    token_data['access_token']
  end

  def request_embed_token(access_token, workspace_id, report_id)
    require 'net/http'
    require 'uri'
    require 'json'

    uri = URI.parse("https://api.powerbi.com/v1.0/myorg/groups/#{workspace_id}/reports/#{report_id}/GenerateToken")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'

    # Request body - can add RLS (Row-Level Security) here
    request.body = {
      accessLevel: 'View'
    }.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end
end
```

**Note**: Consider using the `httparty` or `faraday` gem for cleaner HTTP requests.

### 5. Add Required Gems (Optional but Recommended)

Add to `Gemfile`:

```ruby
# Power BI integration
gem 'httparty', '~> 0.21'  # For HTTP requests to Power BI API
# OR
gem 'faraday', '~> 2.7'    # Alternative HTTP client
```

Run `bundle install`

### 6. Update DashboardsController

In `/app/controllers/dashboards_controller.rb`, replace the `get_embed_config` method to use the real service:

```ruby
def get_embed_config(form_template)
  service = PowerBiService.new(session)
  token_data = service.generate_embed_token(
    form_template.powerbi_workspace_id,
    form_template.powerbi_report_id
  )

  {
    type: 'report',
    id: form_template.powerbi_report_id,
    embedUrl: powerbi_embed_url(form_template),
    accessToken: token_data[:token],
    tokenExpiration: token_data[:expiration],
    settings: {
      filterPaneEnabled: false,
      navContentPaneEnabled: true,
      background: 'transparent'
    }
  }
end
```

### 7. Testing Checklist

Before deploying to production:

- [ ] Azure AD app registration created and configured
- [ ] Service principal added to Power BI workspaces
- [ ] Environment variables added to production `.env`
- [ ] Test with a real Power BI report
- [ ] Verify embed token generation works
- [ ] Test token refresh logic (tokens expire after ~1 hour)
- [ ] Test with multiple concurrent users
- [ ] Verify CSP allows Power BI domains (check browser console)
- [ ] Test error handling (invalid workspace/report IDs)
- [ ] Verify RLS (Row-Level Security) if applicable

### 8. Row-Level Security (RLS) Implementation (Optional)

If you need to filter dashboard data based on the logged-in user:

1. **In Power BI Desktop**:
   - Create a role with a DAX filter (e.g., `[EmployeeID] = USERNAME()`)
   - Publish the report to Power BI Service

2. **Update PowerBiService**:
   ```ruby
   def request_embed_token(access_token, workspace_id, report_id)
     # ... existing code ...

     # Add identity for RLS
     request.body = {
       accessLevel: 'View',
       identities: [
         {
           username: @user_session[:user]['employee_id'],  # Or email
           roles: ['YourRoleName'],
           datasets: [dataset_id]  # Get this from Power BI
         }
       ]
     }.to_json

     # ... rest of code ...
   end
   ```

3. **Test RLS**:
   - Verify different users see different data
   - Test with users who should have no data access

### 9. Troubleshooting

**Error: "PowerBINotAuthorizedException"**
- Check that service principal has access to the workspace
- Verify API permissions in Azure AD
- Ensure admin consent was granted

**Error: "Invalid embed token"**
- Verify workspace_id and report_id are correct
- Check that the token hasn't expired
- Ensure CSP allows Power BI domains

**Error: "CORS blocked"**
- Update CSP configuration
- Verify Power BI URLs are whitelisted

**Dashboard loads but shows no data**
- Check RLS configuration
- Verify dataset refresh schedule
- Test report in Power BI Service directly

### 10. Security Considerations

1. **Never expose client secrets** in frontend code or version control
2. **Use environment variables** for all sensitive configuration
3. **Implement proper access control** in DashboardsController
4. **Consider enabling audit logging** for Power BI access
5. **Rotate client secrets** periodically (every 90 days recommended)
6. **Monitor API usage** in Azure portal
7. **Implement rate limiting** if needed for API calls

### 11. Resources

- [Power BI Embedded Documentation](https://learn.microsoft.com/en-us/power-bi/developer/embedded/)
- [Generate Embed Token API](https://learn.microsoft.com/en-us/rest/api/power-bi/embed-token/generate-token)
- [Row-Level Security (RLS)](https://learn.microsoft.com/en-us/power-bi/developer/embedded/embedded-row-level-security)
- [Power BI REST API Reference](https://learn.microsoft.com/en-us/rest/api/power-bi/)
- [Azure AD App Registration Guide](https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)

## Questions?

Contact your Power BI administrator or Azure AD administrator for help with:
- Azure AD app registration
- Service principal configuration
- Power BI workspace access
- Government cloud endpoints

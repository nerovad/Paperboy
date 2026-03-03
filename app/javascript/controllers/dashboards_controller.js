// app/javascript/controllers/dashboards_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "formSelect",
    "container",
    "loading",
    "error",
    "errorMessage",
    "reportContainer"
  ]

  connect() {
    console.log("Dashboards controller connected")

    // Load Power BI JavaScript SDK
    this.loadPowerBiSDK().then(() => {
      // If a form is pre-selected, load its dashboard
      const embedConfig = this.getEmbedConfig()
      if (embedConfig) {
        this.embedReport(embedConfig)
      }
    }).catch(error => {
      console.error("Failed to load Power BI SDK:", error)
      this.showError("Failed to load Power BI library. Please refresh the page.")
    })
  }

  disconnect() {
    // Clean up Power BI report instance
    if (this.report) {
      this.report.off()
      this.report = null
    }
  }

  loadDashboard(event) {
    // Form selector changed - submit form to reload page with selected dashboard
    event.target.form.requestSubmit()
  }

  async loadPowerBiSDK() {
    // Check if SDK is already loaded
    if (window.powerbi) {
      return Promise.resolve()
    }

    // Dynamically load Power BI JavaScript SDK
    return new Promise((resolve, reject) => {
      const script = document.createElement('script')
      script.src = 'https://cdn.jsdelivr.net/npm/powerbi-client@2.23.1/dist/powerbi.min.js'
      script.onload = resolve
      script.onerror = reject
      document.head.appendChild(script)
    })
  }

  getEmbedConfig() {
    if (!this.hasReportContainerTarget) return null

    const configData = this.reportContainerTarget.dataset.embedConfig
    return configData ? JSON.parse(configData) : null
  }

  async embedReport(config) {
    this.showLoading()

    try {
      // Get Power BI service instance
      const powerbi = window.powerbi

      // Reset the container
      powerbi.reset(this.reportContainerTarget)

      // Embed configuration
      const embedConfig = {
        type: 'report',
        id: config.id,
        embedUrl: config.embedUrl,
        accessToken: config.accessToken,
        tokenType: window.models?.TokenType?.Embed || 0,
        settings: {
          filterPaneEnabled: config.settings?.filterPaneEnabled ?? false,
          navContentPaneEnabled: config.settings?.navContentPaneEnabled ?? true,
          background: config.settings?.background ?? 'transparent',
          layoutType: window.models?.LayoutType?.Custom || 0,
          customLayout: {
            displayOption: window.models?.DisplayOption?.FitToWidth || 0
          }
        }
      }

      // Embed the report
      this.report = powerbi.embed(this.reportContainerTarget, embedConfig)

      // Handle events
      this.report.on('loaded', () => {
        console.log('Report loaded successfully')
        this.showReport()
        this.scheduleTokenRefresh(config.tokenExpiration)
      })

      this.report.on('rendered', () => {
        console.log('Report rendered successfully')
      })

      this.report.on('error', (event) => {
        console.error('Power BI error:', event.detail)
        this.showError('An error occurred while loading the dashboard.')
      })

    } catch (error) {
      console.error('Error embedding report:', error)
      this.showError('Failed to load dashboard. Please try again.')
    }
  }

  scheduleTokenRefresh(expiration) {
    // Refresh token 5 minutes before expiration
    const expirationTime = new Date(expiration)
    const refreshTime = expirationTime.getTime() - (5 * 60 * 1000)
    const now = Date.now()
    const delay = refreshTime - now

    if (delay > 0) {
      setTimeout(() => this.refreshToken(), delay)
    }
  }

  async refreshToken() {
    console.log('Refreshing Power BI access token...')

    try {
      const formId = this.formSelectTarget.value
      const response = await fetch('/dashboards/embed_token', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ form_id: formId })
      })

      if (!response.ok) {
        throw new Error('Failed to refresh token')
      }

      const data = await response.json()

      // Update token in the report
      await this.report.setAccessToken(data.accessToken)

      // Schedule next refresh
      this.scheduleTokenRefresh(data.tokenExpiration)

      console.log('Token refreshed successfully')
    } catch (error) {
      console.error('Error refreshing token:', error)
      // Don't show error to user - token might still be valid
    }
  }

  retry() {
    const config = this.getEmbedConfig()
    if (config) {
      this.embedReport(config)
    } else {
      window.location.reload()
    }
  }

  showLoading() {
    if (this.hasLoadingTarget) this.loadingTarget.style.display = 'block'
    if (this.hasErrorTarget) this.errorTarget.style.display = 'none'
    if (this.hasReportContainerTarget) this.reportContainerTarget.style.display = 'none'
  }

  showReport() {
    if (this.hasLoadingTarget) this.loadingTarget.style.display = 'none'
    if (this.hasErrorTarget) this.errorTarget.style.display = 'none'
    if (this.hasReportContainerTarget) this.reportContainerTarget.style.display = 'block'
  }

  showError(message) {
    if (this.hasLoadingTarget) this.loadingTarget.style.display = 'none'
    if (this.hasReportContainerTarget) this.reportContainerTarget.style.display = 'none'
    if (this.hasErrorTarget) {
      this.errorTarget.style.display = 'flex'
      if (this.hasErrorMessageTarget) {
        this.errorMessageTarget.textContent = message
      }
    }
  }
}

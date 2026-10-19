import { Controller } from "@hotwired/stimulus"

// Draws one SQL Dashboards chart from the rows the server already shaped
// (SqlDashboards::ChartData). Chart.js and Chartkick are fetched the first
// time a chart appears, so no other page pays for them.
export default class extends Controller {
  static values = { type: String, series: Array, options: Object }

  async connect() {
    await import("Chart.bundle")
    await import("chartkick")
    if (!this.element.isConnected) return

    this.chart = new window.Chartkick[this.typeValue](this.element, this.seriesValue, this.optionsValue)
  }

  disconnect() {
    this.chart?.destroy()
    this.chart = null
  }
}

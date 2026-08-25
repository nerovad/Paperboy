import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["server", "database", "table", "targetServer", "targetDatabase", "status"]
  static values = {
    databasesUrl: String,
    tablesUrl: String,
    selectedDatabase: String,
    selectedTable: String,
    selectedTargetDatabase: String,
  }

  connect() {
    if (this.serverTarget.value) this.loadDatabases()
    if (this.targetServerTarget.value) this.loadTargetDatabases()
  }

  async loadTargetDatabases() {
    this.replaceOptions(this.targetDatabaseTarget, "Loading databases…")
    const loaded = await this.loadOptions(
      this.targetDatabaseTarget,
      this.databasesUrlValue,
      { server: this.targetServerTarget.value },
      "Select a target database"
    )
    if (loaded && this.selectedTargetDatabaseValue) {
      this.targetDatabaseTarget.value = this.selectedTargetDatabaseValue
    }
  }

  async loadDatabases() {
    this.replaceOptions(this.databaseTarget, "Loading databases…")
    this.replaceOptions(this.tableTarget, "Select a database first")
    const loaded = await this.loadOptions(
      this.databaseTarget,
      this.databasesUrlValue,
      { server: this.serverTarget.value },
      "Select a database"
    )
    if (loaded && this.selectedDatabaseValue) {
      this.databaseTarget.value = this.selectedDatabaseValue
      await this.loadTables()
    }
  }

  async loadTables() {
    if (!this.databaseTarget.value) return

    this.replaceOptions(this.tableTarget, "Loading tables…")
    const loaded = await this.loadOptions(
      this.tableTarget,
      this.tablesUrlValue,
      { server: this.serverTarget.value, database: this.databaseTarget.value },
      "Select a table"
    )
    if (loaded && this.selectedTableValue) this.tableTarget.value = this.selectedTableValue
  }

  async loadOptions(select, url, params, prompt) {
    try {
      const query = new URLSearchParams(params)
      const response = await fetch(`${url}?${query}`, { headers: { Accept: "application/json" } })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload.error || "The database could not be queried.")

      this.replaceOptions(select, prompt, payload)
      this.statusTarget.textContent = ""
      return true
    } catch (error) {
      this.replaceOptions(select, prompt)
      this.statusTarget.textContent = error.message
      return false
    }
  }

  replaceOptions(select, prompt, values = []) {
    const options = [new Option(prompt, "")]
    values.forEach((value) => options.push(new Option(value, value)))
    select.replaceChildren(...options)
  }
}

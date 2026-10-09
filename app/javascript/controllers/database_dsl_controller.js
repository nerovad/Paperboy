import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "server", "database", "table", "replicate", "targetCard", "targetServer",
    "targetDatabase", "targetSchema", "targetTable", "status"
  ]
  static values = {
    databasesUrl: String,
    schemasUrl: String,
    tablesUrl: String,
    selectedDatabase: String,
    selectedTable: String,
    selectedTargetDatabase: String,
    selectedTargetSchema: String,
    selectedTargetTable: String,
  }

  connect() {
    if (this.serverTarget.value) this.loadDatabases()
    if (this.replicateTarget.value === "1") this.enableReplication()
  }

  showReplication() {
    this.replicateTarget.value = "1"
    this.enableReplication()
    this.targetSchemaTarget.focus()
  }

  enableReplication() {
    this.targetCardTarget.hidden = false
    this.targetInputs().forEach(input => { input.required = true })
    if (this.targetServerTarget.value) this.loadTargetDatabases()
  }

  sourceTableChanged() {
    if (this.replicateTarget.value !== "1" || this.targetTableTarget.value) return

    this.defaultTargetTable()
  }

  defaultTargetTable() {
    const name = this.tableTarget.value.split(".").pop() || ""
    if (this.hasOption(this.targetTableTarget, name)) this.targetTableTarget.value = name
  }

  targetInputs() {
    return [this.targetServerTarget, this.targetDatabaseTarget, this.targetSchemaTarget, this.targetTableTarget]
  }

  async loadTargetDatabases() {
    this.replaceOptions(this.targetDatabaseTarget, "Loading databases…")
    this.replaceOptions(this.targetSchemaTarget, "Select a target database first")
    this.replaceOptions(this.targetTableTarget, "Select a target schema first")
    const loaded = await this.loadOptions(
      this.targetDatabaseTarget,
      this.databasesUrlValue,
      { server: this.targetServerTarget.value },
      "Select a target database"
    )
    if (!loaded) return

    this.applySelection(this.targetDatabaseTarget, this.selectedTargetDatabaseValue)
    this.selectedTargetDatabaseValue = ""
    if (this.targetDatabaseTarget.value) await this.loadTargetSchemas()
  }

  async loadTargetSchemas() {
    if (!this.targetDatabaseTarget.value) return

    this.replaceOptions(this.targetSchemaTarget, "Loading schemas…")
    this.replaceOptions(this.targetTableTarget, "Select a target schema first")
    const loaded = await this.loadOptions(
      this.targetSchemaTarget,
      this.schemasUrlValue,
      { server: this.targetServerTarget.value, database: this.targetDatabaseTarget.value },
      "Select a target schema"
    )
    if (!loaded) return

    this.applySelection(this.targetSchemaTarget, this.selectedTargetSchemaValue)
    this.selectedTargetSchemaValue = ""
    if (this.targetSchemaTarget.value) await this.loadTargetTables()
  }

  async loadTargetTables() {
    if (!this.targetDatabaseTarget.value || !this.targetSchemaTarget.value) return

    this.replaceOptions(this.targetTableTarget, "Loading tables…")
    const loaded = await this.loadOptions(
      this.targetTableTarget,
      this.tablesUrlValue,
      {
        server: this.targetServerTarget.value,
        database: this.targetDatabaseTarget.value,
        schema: this.targetSchemaTarget.value
      },
      "Select a target table"
    )
    if (!loaded) return

    if (this.selectedTargetTableValue) {
      this.applySelection(this.targetTableTarget, this.selectedTargetTableValue)
      this.selectedTargetTableValue = ""
    } else {
      this.defaultTargetTable()
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
    if (!loaded || !this.selectedDatabaseValue) return

    this.applySelection(this.databaseTarget, this.selectedDatabaseValue)
    this.selectedDatabaseValue = ""
    if (this.databaseTarget.value) await this.loadTables()
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
    if (!loaded || !this.selectedTableValue) return

    this.applySelection(this.tableTarget, this.selectedTableValue)
    this.selectedTableValue = ""
  }

  applySelection(select, value) {
    if (value && this.hasOption(select, value)) select.value = value
  }

  hasOption(select, value) {
    return Array.from(select.options).some(option => option.value === value)
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

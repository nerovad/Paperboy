import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input", "results", "contact", "email", "phone", "accountItemInput",
    "accountItemResult", "accountItemCard"
  ]
  static values = { employeesUrl: String, hierarchyUrl: String, accountItemsUrl: String }

  connect() {
    this.searchTimer = null
    this.searchRequest = null
    this.accountItemTimer = null
    this.accountItemRequest = null
  }

  disconnect() {
    clearTimeout(this.searchTimer)
    this.searchRequest?.abort()
    clearTimeout(this.accountItemTimer)
    this.accountItemRequest?.abort()
  }

  searchAccountItems() {
    clearTimeout(this.accountItemTimer)
    this.accountItemRequest?.abort()
    this.accountItemResultTarget.hidden = true

    const query = this.accountItemInputTarget.value.trim()
    if (!query) return

    this.accountItemTimer = setTimeout(() => this.loadAccountItems(query), 250)
  }

  async loadAccountItems(query) {
    this.accountItemRequest = new AbortController()
    const url = new URL(this.accountItemsUrlValue, window.location.origin)
    url.searchParams.set("q", query)

    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.accountItemRequest.signal
      })
      if (!response.ok) return

      const { tables } = await response.json()
      this.accountItemResultTarget.textContent = tables.length
        ? `Found in: ${tables.join(", ")}.`
        : "Not found."
      this.accountItemResultTarget.hidden = false
    } catch (error) {
      if (error.name !== "AbortError") throw error
    }
  }

  search() {
    clearTimeout(this.searchTimer)
    this.searchRequest?.abort()
    this.hideResults()
    this.contactTarget.hidden = true
    this.resetAccountItemLookup()
    window.dispatchEvent(new CustomEvent("coa-organization-cleared"))

    const query = this.inputTarget.value.trim()
    if (!query) return

    this.searchTimer = setTimeout(() => this.loadEmployees(query), 250)
  }

  keydown(event) {
    if (event.key === "Escape") this.hideResults()
  }

  async loadEmployees(query) {
    this.searchRequest = new AbortController()
    const url = new URL(this.employeesUrlValue, window.location.origin)
    url.searchParams.set("q", query)
    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.searchRequest.signal
      })
      if (!response.ok) return

      this.renderResults(await response.json())
    } catch (error) {
      if (error.name !== "AbortError") throw error
    }
  }

  renderResults(employees) {
    this.resultsTarget.replaceChildren()
    employees.forEach(employee => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "coa-customer-result"
      button.setAttribute("role", "option")
      button.textContent = `${employee.label} — Unit ${employee.unit || "not assigned"}`
      button.addEventListener("click", () => this.select(employee))
      this.resultsTarget.append(button)
    })

    if (!employees.length) {
      const message = document.createElement("p")
      message.className = "coa-customer-results__empty"
      message.textContent = "No employees found."
      this.resultsTarget.append(message)
    }
    this.resultsTarget.hidden = false
  }

  async select(employee) {
    this.inputTarget.value = employee.label
    this.hideResults()

    const url = new URL(this.hierarchyUrlValue, window.location.origin)
    url.searchParams.set("employee_id", employee.value)
    const response = await fetch(url, { headers: { Accept: "application/json" } })
    if (!response.ok) return

    this.renderHierarchy(await response.json())
  }

  renderHierarchy(payload) {
    this.renderContact(payload.contact)
    this.accountItemCardTarget.hidden = false
    this.publishOrganization(payload)
  }

  resetAccountItemLookup() {
    clearTimeout(this.accountItemTimer)
    this.accountItemRequest?.abort()
    this.accountItemInputTarget.value = ""
    this.accountItemResultTarget.replaceChildren()
    this.accountItemResultTarget.hidden = true
    this.accountItemCardTarget.hidden = true
  }

  renderContact(contact) {
    this.renderContactValue(this.emailTarget, contact.email, "mailto:")
    this.renderContactValue(this.phoneTarget, contact.phone, "tel:")
    this.contactTarget.hidden = false
  }

  renderContactValue(target, value, protocol) {
    target.replaceChildren()
    if (!value) {
      target.textContent = "Not available"
      return
    }

    const link = document.createElement("a")
    link.href = `${protocol}${value}`
    link.textContent = value
    target.append(link)
  }

  publishOrganization(payload) {
    const ids = Object.fromEntries(payload.nodes.map(node => [node.level, node.id]))
    if (!ids.Agency || !ids.Division || !ids.Department || !ids.Unit) {
      window.dispatchEvent(new CustomEvent("coa-organization-cleared"))
      return
    }

    window.dispatchEvent(new CustomEvent("coa-organization-selected", {
      detail: {
        agency: ids.Agency,
        division: ids.Division,
        department: ids.Department,
        unit: ids.Unit,
        customerName: payload.employee.label,
        nodes: payload.nodes
      }
    }))
  }

  hideResults() {
    this.resultsTarget.hidden = true
    this.resultsTarget.replaceChildren()
  }
}

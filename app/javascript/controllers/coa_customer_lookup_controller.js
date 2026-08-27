import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input", "results", "hierarchy", "customerName", "tree", "empty",
    "contact", "email", "phone"
  ]
  static values = { employeesUrl: String, hierarchyUrl: String }

  connect() {
    this.searchTimer = null
    this.searchRequest = null
  }

  disconnect() {
    clearTimeout(this.searchTimer)
    this.searchRequest?.abort()
  }

  search() {
    clearTimeout(this.searchTimer)
    this.searchRequest?.abort()
    this.hideResults()
    this.hierarchyTarget.hidden = true
    this.contactTarget.hidden = true
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
    this.customerNameTarget.textContent = payload.employee.label
    this.treeTarget.replaceChildren()
    this.emptyTarget.hidden = payload.nodes.length > 0

    if (payload.nodes.length) {
      this.treeTarget.append(this.buildBranch(payload.nodes, 0))
    }
    this.hierarchyTarget.hidden = false
    this.renderContact(payload.contact)
    this.renderBillingString(payload.nodes)
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

  renderBillingString(nodes) {
    const ids = Object.fromEntries(nodes.map(node => [node.level, node.id]))
    if (!ids.Agency || !ids.Division || !ids.Department || !ids.Unit) {
      window.dispatchEvent(new CustomEvent("coa-organization-cleared"))
      return
    }

    window.dispatchEvent(new CustomEvent("coa-organization-selected", {
      detail: {
        agency: ids.Agency,
        division: ids.Division,
        department: ids.Department,
        unit: ids.Unit
      }
    }))
  }

  buildBranch(nodes, index) {
    const list = document.createElement("ul")
    if (index === 0) list.className = "coa-account-tree"
    const item = document.createElement("li")
    const node = nodes[index]
    const label = document.createElement("span")
    label.append(`${node.level} - `)
    const code = document.createElement("code")
    code.textContent = node.id
    const name = document.createElement("strong")
    name.textContent = node.name || "Name unavailable"
    label.append(code, " - ", name)
    item.append(label)

    if (index + 1 < nodes.length) item.append(this.buildBranch(nodes, index + 1))
    list.append(item)
    return list
  }

  hideResults() {
    this.resultsTarget.hidden = true
    this.resultsTarget.replaceChildren()
  }
}

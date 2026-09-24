import { Controller } from "@hotwired/stimulus"

// Pick a person the way the Chart of Accounts employee lookup does: type a
// name or employee id, choose from "Last, First (id) — Unit 4641". The chosen
// employee id goes in a hidden field; the visible box only searches.
//
//   <div data-controller="aim-person-search" data-aim-person-search-url-value="/aim/people">
//     <input type="search" data-aim-person-search-target="input" ...>
//     <input type="hidden" name="owner" data-aim-person-search-target="value">
//     <div data-aim-person-search-target="results" hidden></div>
export default class extends Controller {
  static targets = ["input", "value", "results"]
  static values = { url: String }

  connect() {
    this.timer = null
    this.request = null
  }

  disconnect() {
    clearTimeout(this.timer)
    this.request?.abort()
  }

  search() {
    clearTimeout(this.timer)
    this.request?.abort()
    this.valueTarget.value = ""
    this.hide()
    const query = this.inputTarget.value.trim()
    if (!query) return
    this.timer = setTimeout(() => this.load(query), 250)
  }

  keydown(event) {
    if (event.key === "Escape") this.hide()
    if (event.key === "Enter") event.preventDefault()
  }

  async load(query) {
    this.request = new AbortController()
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, signal: this.request.signal })
      if (!response.ok) return
      this.render(await response.json())
    } catch (error) {
      if (error.name !== "AbortError") throw error
    }
  }

  render(people) {
    this.resultsTarget.replaceChildren()
    people.forEach((person) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "coa-customer-result"
      button.setAttribute("role", "option")
      button.textContent = `${person.label} — Unit ${person.unit || "not assigned"}`
      button.addEventListener("click", () => this.select(person))
      this.resultsTarget.append(button)
    })
    if (!people.length) {
      const message = document.createElement("p")
      message.className = "coa-customer-results__empty"
      message.textContent = "No employees found."
      this.resultsTarget.append(message)
    }
    this.resultsTarget.hidden = false
  }

  select(person) {
    this.inputTarget.value = `${person.label} — Unit ${person.unit || "not assigned"}`
    this.valueTarget.value = person.value
    this.hide()
    this.element.dispatchEvent(new CustomEvent("aim-person-search:selected", { bubbles: true }))
  }

  hide() {
    this.resultsTarget.hidden = true
  }
}

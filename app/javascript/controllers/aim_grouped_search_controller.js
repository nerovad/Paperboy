import { Controller } from "@hotwired/stimulus"

// A searchable pick-list for a <select> with <optgroup>s, keeping the groups:
// AIM's person picker (people under each budget unit) and budget unit lists
// (units under each agency). The shared searchable-select flattens groups and
// matches one run of letters; this keeps the headings and matches loosely --
// every word typed must appear somewhere in the option or its group, in any
// order, ignoring case and punctuation ("allyn cahoon", "cahoon 4703").
//
// The <select> stays the source of truth: it submits and carries `required`.
// A group whose data-unit equals the select's data-priority-unit is listed
// first, headed "This invoice's BU"; the Move dialog sets it. Dispatch
// "aim-grouped-search:reset" on the select to clear the choice.
//
//   <select data-controller="aim-grouped-search"> <optgroup label=… data-unit=…> … </select>
const MAX_RESULTS = 200

export default class extends Controller {
  static values = { placeholder: String }

  connect() {
    this.select = this.element
    if (!(this.select instanceof HTMLSelectElement)) return

    this.select.classList.add("aim-grouped-search__native")
    this.select.tabIndex = -1
    this.box = document.createElement("div")
    this.box.className = "aim-grouped-search"
    this.input = document.createElement("input")
    this.input.type = "text"
    this.input.className = "aim-grouped-search__input"
    this.input.autocomplete = "off"
    this.input.placeholder = this.placeholderValue || "Type to search…"
    this.input.setAttribute("aria-label", this.select.getAttribute("aria-label") || "Search")
    this.list = document.createElement("ul")
    this.list.className = "aim-grouped-search__list"
    this.list.setAttribute("role", "listbox")
    this.list.hidden = true
    this.box.append(this.input, this.list)
    this.select.before(this.box)

    // Clicking in shows the whole list, the current choice highlighted; only
    // typing filters. (Filtering by the chosen text left just that one.)
    this.input.addEventListener("input", () => { this.showAll = false; this.render() })
    this.input.addEventListener("focus", () => { this.input.select(); this.showAll = true; this.render() })
    this.input.addEventListener("keydown", (event) => this.keydown(event))
    this.input.addEventListener("blur", () => setTimeout(() => this.settle(), 150))
    this.list.addEventListener("mousedown", (event) => event.preventDefault())
    this.list.addEventListener("click", (event) => {
      const item = event.target.closest("[data-value]")
      if (item) this.choose(item.dataset.value)
    })
    this.onReset = () => { this.select.value = ""; this.input.value = "" }
    this.select.addEventListener("aim-grouped-search:reset", this.onReset)
    this.onRefresh = () => this.showChosen()
    this.select.addEventListener("aim-grouped-search:refresh", this.onRefresh)
    this.showChosen()
  }

  disconnect() {
    this.select?.removeEventListener("aim-grouped-search:reset", this.onReset)
    this.select?.removeEventListener("aim-grouped-search:refresh", this.onRefresh)
    this.box?.remove()
    this.select?.classList.remove("aim-grouped-search__native")
  }

  // [{ label, unit, options: [{ value, text, search }] }], the priority group first.
  groups() {
    const priority = this.select.dataset.priorityUnit || ""
    const groups = Array.from(this.select.children).flatMap((child) => {
      if (child.tagName === "OPTGROUP") {
        return [{ label: child.label, unit: child.dataset.unit || "", options: this.optionsOf(child.children, child.label) }]
      }
      return child.value ? [{ label: "", unit: "", options: this.optionsOf([child], "") }] : []
    })
    const first = groups.filter((g) => priority && g.unit === priority)
    first.forEach((g) => { g.label = `This invoice's BU · ${g.label}` })
    return first.concat(groups.filter((g) => !first.includes(g)))
  }

  optionsOf(options, groupLabel) {
    return Array.from(options).filter((o) => o.value && !o.disabled)
      .map((o) => ({ value: o.value, text: o.text, search: this.normalize(`${o.text} ${groupLabel}`) }))
  }

  render() {
    const words = this.showAll ? [] : this.normalize(this.input.value).split(" ").filter(Boolean)
    this.list.replaceChildren()
    this.items = []
    this.groups().forEach((group) => {
      const matches = group.options.filter((o) => words.every((w) => o.search.includes(w) || o.search.replace(/ /g, "").includes(w)))
      if (matches.length === 0 || this.items.length >= MAX_RESULTS) return
      if (group.label) {
        const heading = document.createElement("li")
        heading.className = "aim-grouped-search__heading"
        heading.setAttribute("role", "presentation")
        heading.textContent = group.label
        this.list.append(heading)
      }
      matches.slice(0, MAX_RESULTS - this.items.length).forEach((o) => {
        const item = document.createElement("li")
        item.className = "aim-grouped-search__option"
        item.setAttribute("role", "option")
        item.dataset.value = o.value
        item.textContent = o.text
        this.list.append(item)
        this.items.push(item)
      })
    })
    if (this.items.length === 0) {
      const empty = document.createElement("li")
      empty.className = "aim-grouped-search__empty"
      empty.textContent = "No matches"
      this.list.append(empty)
    }
    this.list.hidden = false
    const chosen = this.items.findIndex((item) => item.dataset.value === this.select.value)
    this.highlight(this.showAll && chosen >= 0 ? chosen : 0)
  }

  keydown(event) {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      if (this.list.hidden) { this.showAll = true; return this.render() }
      this.highlight(this.active + (event.key === "ArrowDown" ? 1 : -1))
    } else if (event.key === "Enter") {
      if (this.list.hidden || !this.items?.length) return
      event.preventDefault()
      this.choose(this.items[this.active].dataset.value)
    } else if (event.key === "Escape" && !this.list.hidden) {
      event.stopPropagation()
      this.list.hidden = true
    }
  }

  highlight(index) {
    if (!this.items?.length) return
    this.active = (index + this.items.length) % this.items.length
    this.items.forEach((item, i) => item.classList.toggle("is-active", i === this.active))
    this.items[this.active].scrollIntoView({ block: "nearest" })
  }

  choose(value) {
    this.select.value = value
    this.select.dispatchEvent(new Event("change", { bubbles: true }))
    this.showChosen()
    this.list.hidden = true
  }

  // Leaving the box: what is shown is what is chosen; cleared text clears it.
  settle() {
    this.list.hidden = true
    if (this.input.value.trim() === "") this.select.value = ""
    this.showChosen()
  }

  showChosen() {
    const chosen = this.select.selectedOptions[0]
    this.input.value = chosen && chosen.value ? chosen.text : ""
  }

  normalize(text) {
    return text.toLowerCase().replace(/[^a-z0-9]+/g, " ").replace(/\s+/g, " ").trim()
  }
}

import { Controller } from "@hotwired/stimulus"

// Type-to-search for a single-choice <select>, without Choices.js.
//
// A native select does jump to matches as you type, but never shows what you
// typed. This puts a text input + filtered listbox (the ARIA combobox pattern)
// in front of the select. The <select> stays in the form as the source of
// truth: it is what submits, what `required` validates, and what fires the
// `change` that conditional_fields_controller listens for. It is visually
// hidden, not display:none, so a browser validation bubble still has
// somewhere to point.
//
// Anything that rewrites the select behind our back is picked up: options
// swapped in by a cascade controller (MutationObserver), disabled/required/
// class toggles (same observer), and a value set programmatically followed by
// a `change` event.
//
//   <select class="form-control" data-controller="searchable-select">…</select>
//
// Multi-selects are left alone — those are what Choices is for.
const MAX_RESULTS = 200
let uid = 0

export default class extends Controller {
  connect() {
    this.select = this.element
    if (!(this.select instanceof HTMLSelectElement) || this.select.multiple) return

    this.id = `searchable-select-${++uid}`
    this.matches = []
    this.activeIndex = -1

    this.build()
    this.syncFromSelect()

    this.onSelectChange = () => this.syncFromSelect()
    this.select.addEventListener("change", this.onSelectChange)

    this.onFormReset = () => setTimeout(() => this.syncFromSelect())
    this.select.form?.addEventListener("reset", this.onFormReset)

    this.observer = new MutationObserver(() => this.syncFromSelect())
    this.observer.observe(this.select, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
      attributeFilter: ["disabled", "required", "class"]
    })

    // Turbo snapshots the page while controllers are still connected; put the
    // plain select back first so a restored page doesn't carry a dead widget.
    this.beforeCache = () => this.teardown()
    document.addEventListener("turbo:before-cache", this.beforeCache)
  }

  disconnect() {
    this.teardown()
  }

  teardown() {
    if (!this.wrapper) return

    this.observer?.disconnect()
    this.select.removeEventListener("change", this.onSelectChange)
    this.select.form?.removeEventListener("reset", this.onFormReset)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    this.select.removeEventListener("invalid", this.onInvalid)
    this.labels.forEach(label => label.removeEventListener("click", this.onLabelClick))

    this.wrapper.remove()
    this.wrapper = null
    this.select.classList.remove("searchable-select__native")
    this.select.removeAttribute("tabindex")
    this.select.removeAttribute("aria-hidden")
  }

  build() {
    this.wrapper = document.createElement("div")
    this.wrapper.className = "searchable-select"

    this.input = document.createElement("input")
    this.input.type = "text"
    this.input.autocomplete = "off"
    this.input.spellcheck = false
    this.input.setAttribute("role", "combobox")
    this.input.setAttribute("aria-autocomplete", "list")
    this.input.setAttribute("aria-expanded", "false")
    this.input.setAttribute("aria-controls", `${this.id}-list`)
    // <label for="…"> points at the hidden select: let it name the input, and
    // send a click on it to the input instead.
    this.labels = Array.from(this.select.labels || [])
    this.onLabelClick = event => {
      event.preventDefault()
      this.input.focus()
    }
    this.labels.forEach(label => {
      this.input.setAttribute("aria-label", label.textContent.trim())
      label.addEventListener("click", this.onLabelClick)
    })

    this.list = document.createElement("ul")
    this.list.id = `${this.id}-list`
    this.list.className = "searchable-select__list"
    this.list.setAttribute("role", "listbox")
    this.list.hidden = true

    this.wrapper.append(this.input, this.list)
    this.select.after(this.wrapper)

    this.select.classList.add("searchable-select__native")
    this.select.tabIndex = -1
    this.select.setAttribute("aria-hidden", "true")

    this.input.addEventListener("focus", () => this.onFocus())
    this.input.addEventListener("mousedown", () => this.onInputMousedown())
    this.input.addEventListener("input", () => this.filter(this.input.value))
    this.input.addEventListener("keydown", event => this.onKeydown(event))
    this.input.addEventListener("blur", () => this.onBlur())

    // mousedown, not click: keep focus in the input so blur doesn't close the
    // list before the pick lands.
    this.list.addEventListener("mousedown", event => {
      event.preventDefault()
      const item = event.target.closest("[role=option]")
      if (item) this.commit(this.matches[Number(item.dataset.index)])
    })

    // reportValidity() on the hidden select shows its bubble over the input;
    // mark the input too so the field reads as the one in error.
    this.onInvalid = () => this.input.classList.add("invalid")
    this.select.addEventListener("invalid", this.onInvalid)
  }

  // --- select -> input -----------------------------------------------------

  syncFromSelect() {
    if (!this.wrapper) return

    const classes = Array.from(this.select.classList).filter(c => c !== "searchable-select__native")
    this.input.className = [...classes, "searchable-select__input"].join(" ")
    this.input.disabled = this.select.disabled
    this.input.placeholder = this.blankOption()?.text || "Select..."

    const selected = this.select.selectedOptions[0]
    const text = selected && selected.value !== "" ? selected.text : ""
    if (document.activeElement !== this.input || !this.isOpen()) this.input.value = text
    if (selected && selected.value !== "") this.input.classList.remove("invalid")

    if (this.isOpen()) this.filter(this.query ?? "")
  }

  blankOption() {
    return Array.from(this.select.options).find(o => o.value === "")
  }

  choosableOptions() {
    return Array.from(this.select.options).filter(o => o.value !== "" && !o.disabled)
  }

  // --- list ----------------------------------------------------------------

  isOpen() {
    return !this.list.hidden
  }

  onFocus() {
    this.input.select()
    this.open()
  }

  onInputMousedown() {
    if (document.activeElement === this.input && !this.isOpen()) this.open()
  }

  open() {
    if (this.input.disabled) return
    this.query = null
    this.filter("")
    this.list.hidden = false
    this.input.setAttribute("aria-expanded", "true")
  }

  close() {
    this.list.hidden = true
    this.input.setAttribute("aria-expanded", "false")
    this.input.removeAttribute("aria-activedescendant")
    this.query = null
  }

  filter(query) {
    this.query = query
    if (!this.isOpen() && query !== "") {
      this.list.hidden = false
      this.input.setAttribute("aria-expanded", "true")
    }

    const needle = query.trim().toLowerCase()
    const all = this.choosableOptions()
    this.matches = needle ? all.filter(o => o.text.toLowerCase().includes(needle)) : all

    // Opening fresh: start on the current selection. Typing: start on the
    // first match, so Enter takes the obvious one.
    const current = this.select.value
    this.activeIndex = needle ? 0 : Math.max(0, this.matches.findIndex(o => o.value === current))
    this.render()
  }

  render() {
    this.list.replaceChildren()

    if (this.matches.length === 0) {
      const empty = document.createElement("li")
      empty.className = "searchable-select__empty"
      empty.textContent = "No matches"
      this.list.append(empty)
      this.input.removeAttribute("aria-activedescendant")
      return
    }

    const current = this.select.value
    this.matches.slice(0, MAX_RESULTS).forEach((option, index) => {
      const item = document.createElement("li")
      item.id = `${this.id}-opt-${index}`
      item.className = "searchable-select__option"
      item.setAttribute("role", "option")
      item.dataset.index = index
      item.textContent = option.text
      item.setAttribute("aria-selected", option.value === current ? "true" : "false")
      this.list.append(item)
    })

    if (this.matches.length > MAX_RESULTS) {
      const more = document.createElement("li")
      more.className = "searchable-select__empty"
      more.textContent = `${this.matches.length - MAX_RESULTS} more — keep typing to narrow`
      this.list.append(more)
    }

    this.highlight(this.activeIndex)
  }

  highlight(index) {
    const count = Math.min(this.matches.length, MAX_RESULTS)
    if (count === 0) return

    this.activeIndex = (index + count) % count
    this.list.querySelectorAll(".is-active").forEach(el => el.classList.remove("is-active"))

    const item = this.list.querySelector(`#${this.id}-opt-${this.activeIndex}`)
    if (!item) return
    item.classList.add("is-active")
    item.scrollIntoView({ block: "nearest" })
    this.input.setAttribute("aria-activedescendant", item.id)
  }

  // --- input -> select -----------------------------------------------------

  onKeydown(event) {
    switch (event.key) {
    case "ArrowDown":
    case "ArrowUp":
      event.preventDefault()
      if (!this.isOpen()) return this.open()
      return this.highlight(this.activeIndex + (event.key === "ArrowDown" ? 1 : -1))
    case "Enter":
      if (!this.isOpen()) return
      // Never let Enter in the search box submit the form.
      event.preventDefault()
      return this.commit(this.matches[this.activeIndex])
    case "Escape":
      if (!this.isOpen()) return
      event.preventDefault()
      this.close()
      return this.syncFromSelect()
    case "Tab":
      // Typed something and a match is highlighted: Tab takes it.
      if (this.isOpen() && this.query) this.commit(this.matches[this.activeIndex], { keepFocus: true })
    }
  }

  onBlur() {
    if (!this.isOpen()) return

    if (this.query !== null) {
      const typed = this.input.value.trim().toLowerCase()
      if (typed === "") {
        this.setValue("")
      } else {
        const exact = this.choosableOptions().find(o => o.text.trim().toLowerCase() === typed)
        if (exact) this.setValue(exact.value)
      }
    }

    this.close()
    this.syncFromSelect()
  }

  commit(option, { keepFocus = false } = {}) {
    if (!option) return
    this.setValue(option.value)
    this.close()
    this.syncFromSelect()
    if (!keepFocus) this.input.focus()
  }

  setValue(value) {
    if (this.select.value === value) return
    this.select.value = value
    this.select.dispatchEvent(new Event("input", { bubbles: true }))
    this.select.dispatchEvent(new Event("change", { bubbles: true }))
  }
}

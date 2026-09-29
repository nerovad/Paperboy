import { Controller } from "@hotwired/stimulus"

// Fill in AIM's queue counts after the page has drawn, so no screen waits on
// them. Every element inside with data-aim-count="<queue>" (or "my_queue")
// gets its number from /aim/counts; a count that cannot be read stays "–".
export default class extends Controller {
  static values = { url: String }

  // The last counts seen are shown at once, then refreshed in place, so
  // moving between pages does not blink the badges. A fetch that fails is
  // tried once more a few seconds later: a page opened while the server is
  // reloading, or the database blinks, should not leave the badges blank.
  async connect() {
    this.show(this.remembered())
    if (await this.load()) return
    this.retry = setTimeout(() => this.load(), 3000)
  }

  disconnect() {
    clearTimeout(this.retry)
  }

  async load() {
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return false
      const counts = await response.json()
      this.show(counts)
      this.remember(counts)
      return true
    } catch (error) {
      console.warn("AIM counts could not be loaded", error)
      return false
    }
  }

  show(counts) {
    if (!counts) return
    this.fill("my_queue", counts.my_queue)
    this.fill("shared_queues", counts.shared_queues)
    Object.entries(counts.queues || {}).forEach(([queue, count]) => this.fill(queue, count))
  }

  remembered() {
    try {
      return JSON.parse(sessionStorage.getItem(this.storageKey) || "null")
    } catch {
      return null
    }
  }

  remember(counts) {
    try {
      sessionStorage.setItem(this.storageKey, JSON.stringify(counts))
    } catch {
      // Storage refused: the counts still load, just without the head start.
    }
  }

  // The name badge and the Invoices tab ask for only My Queue's count, so
  // they keep their own copy rather than overwrite the sidebar's.
  get storageKey() {
    return `aim-counts:${this.urlValue}`
  }

  // A data-aim-count-base is added to the count: the name badge already holds
  // the Inbox count and shows the two together. The controller's own element
  // may carry data-aim-count as well as its children.
  fill(key, count) {
    const selector = `[data-aim-count="${key}"]`
    const elements = [...this.element.querySelectorAll(selector)]
    if (this.element.matches(selector)) elements.push(this.element)
    elements.forEach((element) => {
      const base = Number(element.dataset.aimCountBase || 0)
      const total = count == null ? (base || null) : base + count
      element.textContent = total ?? "–"
      element.hidden = element.dataset.hideZero !== undefined && !total
    })
  }
}

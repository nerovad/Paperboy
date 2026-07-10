import { Controller } from "@hotwired/stimulus"

const DRAG_THRESHOLD = 6

export default class extends Controller {
  static targets = ["dropzone", "list", "empty", "count", "renameInput", "renameButton"]
  static values = { catalog: Object, selectedGroup: String }

  connect() {
    window.DataRunnerDslGroup = {
      add: data => this.addDraggedDsl(data),
      move: (data, x, y) => this.externalMove(data, x, y),
      drop: (data, x, y) => this.externalDrop(data, x, y)
    }
    this.syncEmpty()
    this.syncRenameButton()
  }

  disconnect() {
    if (window.DataRunnerDslGroup?.move) window.DataRunnerDslGroup = null
  }

  open(event) {
    if (event.type === "keydown" && !["Enter", " "].includes(event.key)) return
    if (this.suppressClickUntil && Date.now() < this.suppressClickUntil) return

    event.preventDefault()
    window.location.href = event.currentTarget.dataset.href
  }

  mousedown(event) {
    if (event.button !== 0) return

    event.preventDefault()
    this.removeGhosts()
    this.source = event.currentTarget
    this.drag = {
      slug: this.source.dataset.dslSlug,
      key: this.source.dataset.dslKey || this.catalogValue[this.source.dataset.dslSlug]?.key,
      enabled: this.source.dataset.dslEnabled === "true",
      origin: "group"
    }
    this.startX = event.clientX
    this.startY = event.clientY
    this.dragging = false
    this.boundMousemove = moveEvent => this.mousemove(moveEvent)
    this.boundMouseup = upEvent => this.mouseup(upEvent)
    document.addEventListener("mousemove", this.boundMousemove, true)
    document.addEventListener("mouseup", this.boundMouseup, true)
  }

  mousemove(event) {
    if (!this.drag) return
    if (event.buttons === 0) {
      this.mouseup(event)
      return
    }

    const distance = Math.hypot(event.clientX - this.startX, event.clientY - this.startY)
    if (!this.dragging && distance < DRAG_THRESHOLD) return

    event.preventDefault()
    this.dragging = true
    this.suppressClickUntil = Date.now() + 700
    this.source.classList.add("dragging")
    this.showGhost(event, this.drag.key)
    this.removeDraggedDsl(this.drag.slug)
  }

  mouseup(event) {
    document.removeEventListener("mousemove", this.boundMousemove, true)
    document.removeEventListener("mouseup", this.boundMouseup, true)
    if (this.dragging) {
      event.preventDefault()
      this.applyMouseDrop(this.drag, event.clientX, event.clientY)
    }
    this.finishDrag()
  }

  externalMove(data, x, y) {
    if (this.pointAcceptsAdd(x, y)) {
      this.addDraggedDsl(data)
      this.setDropHighlight(true)
    } else {
      this.setDropHighlight(false)
    }
  }

  externalDrop(data, x, y) {
    this.applyMouseDrop(data, x, y)
    this.setDropHighlight(false)
  }

  applyMouseDrop(data, x, y) {
    if (!data?.slug) return

    if (data.origin === "nav" && this.pointAcceptsAdd(x, y)) {
      this.addItem(data)
    } else if (data.origin === "group") {
      this.removeItem(data.slug)
    }
    this.sortItems()
    this.syncEmpty()
  }

  addItem(data) {
    if (this.findItem(data.slug)) return

    this.listTarget.appendChild(this.itemElement(data))
  }

  addDraggedDsl(data) {
    this.addItem(data)
    this.sortItems()
    this.syncEmpty()
  }

  removeItem(slug) {
    this.findItem(slug)?.remove()
  }

  removeDraggedDsl(slug) {
    this.removeItem(slug)
    this.sortItems()
    this.syncEmpty()
    this.setDropHighlight(false)
  }

  pointInDropzone(x, y) {
    const target = document.elementFromPoint(x, y)
    return target === this.dropzoneTarget || this.dropzoneTarget.contains(target)
  }

  pointInList(x, y) {
    const target = document.elementFromPoint(x, y)
    return target === this.listTarget || this.listTarget.contains(target)
  }

  pointAcceptsAdd(x, y) {
    return this.pointInDropzone(x, y) || this.pointInSelectedNavGroup(x, y)
  }

  pointInSelectedNavGroup(x, y) {
    if (!this.hasSelectedGroupValue) return false

    const group = document.querySelector(`[data-nav-group="${CSS.escape(this.selectedGroupValue)}"]`)
    if (!group) return false

    const rect = group.getBoundingClientRect()
    return x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom
  }

  setDropHighlight(active) {
    this.dropzoneTarget.classList.toggle("drag-over", active)
  }

  finishDrag() {
    this.source?.classList.remove("dragging")
    this.removeGhost()
    this.setDropHighlight(false)
    this.drag = null
    this.dragging = false
  }

  showGhost(event, label) {
    if (!this.ghost) {
      this.ghost = document.createElement("div")
      this.ghost.className = "drag-ghost"
      this.ghost.textContent = label
      document.body.appendChild(this.ghost)
    }
    this.ghost.style.left = `${event.clientX + 12}px`
    this.ghost.style.top = `${event.clientY + 12}px`
  }

  removeGhost() {
    this.ghost?.remove()
    this.ghost = null
  }

  removeGhosts() {
    document.querySelectorAll(".drag-ghost").forEach(ghost => ghost.remove())
  }

  findItem(slug) {
    return this.itemTargets.find(item => item.dataset.dslSlug === slug)
  }

  itemElement({ slug, key, enabled }) {
    const itemEnabled = enabled ?? this.catalogValue[slug]?.enabled
    const item = document.createElement("div")
    item.className = `dsl-pill${itemEnabled ? " enabled" : ""}`
    item.role = "link"
    item.tabIndex = 0
    item.dataset.dslGroupTarget = "item"
    item.dataset.dslSlug = slug
    item.dataset.dslKey = key
    item.dataset.dslEnabled = itemEnabled ? "true" : "false"
    item.dataset.href = `/data_runner/dsls/${slug}`
    item.dataset.action = "click->dsl-group#open keydown->dsl-group#open mousedown->dsl-group#mousedown"
    item.innerHTML = `<span>${this.escapeHtml(key)}</span><input type="hidden" name="dsl_slugs[]" value="${this.escapeHtml(slug)}">`
    return item
  }

  syncEmpty() {
    this.emptyTarget.hidden = this.itemTargets.length > 0
    if (this.hasCountTarget) {
      this.countTarget.textContent = `${this.itemTargets.length} ${this.itemTargets.length === 1 ? "DSL" : "DSLs"} in this group`
    }
  }

  syncRenameButton() {
    if (!this.hasRenameInputTarget || !this.hasRenameButtonTarget) return

    const currentName = this.normalizedGroupName(this.selectedGroupValue)
    const newName = this.normalizedGroupName(this.renameInputTarget.value)
    this.renameButtonTarget.disabled = newName.length === 0 || newName === currentName
  }

  sortItems() {
    this.itemTargets
      .sort((left, right) => left.dataset.dslKey.localeCompare(right.dataset.dslKey, undefined, { sensitivity: "base" }))
      .forEach(item => this.listTarget.appendChild(item))
  }

  normalizedGroupName(value) {
    return value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "")
  }

  escapeHtml(value) {
    const element = document.createElement("span")
    element.textContent = value
    return element.innerHTML
  }
}

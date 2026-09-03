import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["customerName", "tree", "empty"]
  static values = { nodes: Array, customerName: String }

  connect() {
    if (this.hasNodesValue) {
      this.organizationSelected({
        detail: { nodes: this.nodesValue, customerName: this.customerNameValue }
      })
    }
  }

  organizationSelected({ detail }) {
    this.customerNameTarget.textContent = detail.customerName || ""
    this.customerNameTarget.hidden = !detail.customerName
    this.treeTarget.replaceChildren()
    this.emptyTarget.hidden = detail.nodes.length > 0

    if (detail.nodes.length) this.treeTarget.append(this.buildBranch(detail.nodes, 0))
    this.element.hidden = false
  }

  clear() {
    this.element.hidden = true
    this.customerNameTarget.textContent = ""
    this.treeTarget.replaceChildren()
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
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "actionPanel", "actionsContainer"]

  connect() {
    this.selectedGroupId = null
  }

  select(event) {
    if (event.target.closest('a, button, form')) return

    const row = event.currentTarget
    const groupId = row.dataset.groupId

    if (this.selectedGroupId === groupId) {
      this.deselect()
      return
    }

    this.rowTargets.forEach(r => r.classList.remove('selected'))
    row.classList.add('selected')
    this.selectedGroupId = groupId

    const allActions = this.actionsContainerTarget.querySelectorAll('.task-actions')
    allActions.forEach(a => a.style.display = 'none')

    const actions = this.actionsContainerTarget.querySelector(`.task-actions[data-group-id="${groupId}"]`)
    if (actions) {
      actions.style.display = 'flex'
      this.actionPanelTarget.style.display = 'block'
    }
  }

  deselect() {
    this.rowTargets.forEach(r => r.classList.remove('selected'))
    this.selectedGroupId = null
    this.actionPanelTarget.style.display = 'none'
  }

  closePanel() {
    this.deselect()
  }
}

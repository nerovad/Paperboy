import { Controller } from "@hotwired/stimulus"

// Handles task row selection and displays actions in a panel
export default class extends Controller {
  static targets = ["row", "actionPanel", "actionsContainer"]

  connect() {
    this.selectedTaskId = null
    this.selectedTaskType = null
  }

  select(event) {
    // Don't select if clicking on a link or button inside the row
    if (event.target.closest('a, button, form, select')) {
      return
    }

    const row = event.currentTarget
    const taskId = row.dataset.taskId
    const taskType = row.dataset.taskType

    // If clicking the same row, deselect
    if (this.selectedTaskId === taskId && this.selectedTaskType === taskType) {
      this.deselect()
      return
    }

    // Deselect previous
    this.rowTargets.forEach(r => r.classList.remove('selected'))

    // Select new
    row.classList.add('selected')
    this.selectedTaskId = taskId
    this.selectedTaskType = taskType

    // Show the action panel
    this.showActions(taskType, taskId)
  }

  deselect() {
    this.rowTargets.forEach(r => r.classList.remove('selected'))
    this.selectedTaskId = null
    this.selectedTaskType = null
    this.actionPanelTarget.style.display = 'none'
  }

  showActions(taskType, taskId) {
    // Hide all action sets
    const allActions = this.actionsContainerTarget.querySelectorAll('.task-actions')
    allActions.forEach(a => a.style.display = 'none')

    // Show the selected task's actions
    const selector = `.task-actions[data-task-type="${taskType}"][data-task-id="${taskId}"]`
    const actions = this.actionsContainerTarget.querySelector(selector)
    if (actions) {
      actions.style.display = 'flex'
      this.actionPanelTarget.style.display = 'block'
    }
  }

  // Close panel when clicking outside (optional - can be wired to a backdrop)
  closePanel() {
    this.deselect()
  }
}

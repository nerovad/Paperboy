import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    // Show any flash messages rendered server-side
    this.containerTarget.querySelectorAll('.toast[data-auto-show]').forEach(toast => {
      this.animateIn(toast)
      this.autoDismiss(toast)
    })
  }

  animateIn(toast) {
    requestAnimationFrame(() => toast.classList.add('show'))
  }

  autoDismiss(toast, delay = 5000) {
    setTimeout(() => this.dismiss(toast), delay)
  }

  close(event) {
    this.dismiss(event.currentTarget.closest('.toast'))
  }

  dismiss(toast) {
    if (!toast) return
    toast.classList.remove('show')
    toast.addEventListener('transitionend', () => toast.remove(), { once: true })
    // Fallback removal if transition doesn't fire
    setTimeout(() => toast.remove(), 400)
  }

  // Call this from other controllers to show a toast programmatically
  static show(type, message) {
    let container = document.getElementById('toast-container')
    if (!container) {
      container = document.createElement('div')
      container.id = 'toast-container'
      container.classList.add('toast-container')
      container.setAttribute('data-controller', 'toast')
      container.setAttribute('data-toast-target', 'container')
      document.body.appendChild(container)
    }

    const toast = document.createElement('div')
    toast.className = `toast toast-${type}`
    toast.innerHTML = `
      <span class="toast-message">${message}</span>
      <button class="toast-close" data-action="click->toast#close">&times;</button>
    `
    container.appendChild(toast)

    requestAnimationFrame(() => toast.classList.add('show'))
    setTimeout(() => {
      toast.classList.remove('show')
      toast.addEventListener('transitionend', () => toast.remove(), { once: true })
      setTimeout(() => toast.remove(), 400)
    }, 5000)
  }
}

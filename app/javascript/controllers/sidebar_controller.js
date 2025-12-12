// app/javascript/controllers/sidebar_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle() {
    const sidebar = document.querySelector('.sidebar')
    const overlay = document.querySelector('.sidebar-overlay')

    sidebar.classList.toggle('open')
    overlay.classList.toggle('open')
  }

  close() {
    const sidebar = document.querySelector('.sidebar')
    const overlay = document.querySelector('.sidebar-overlay')

    sidebar.classList.remove('open')
    overlay.classList.remove('open')
  }
}

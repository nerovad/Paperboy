import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { activeTab: { type: String, default: "documentation" } }

  connect() {
    this.showTab(this.activeTabValue)
  }

  switch(event) {
    event.preventDefault()
    const tab = event.currentTarget.dataset.tab
    this.activeTabValue = tab
    this.showTab(tab)

    const url = new URL(window.location)
    if (tab === "documentation") {
      url.searchParams.delete("tab")
    } else {
      url.searchParams.set("tab", tab)
    }
    history.replaceState({}, "", url)
  }

  showTab(activeTab) {
    this.tabTargets.forEach(tab => {
      tab.classList.toggle("active", tab.dataset.tab === activeTab)
    })
    this.panelTargets.forEach(panel => {
      panel.hidden = panel.dataset.tab !== activeTab
    })
  }
}

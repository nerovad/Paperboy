import { Controller } from "@hotwired/stimulus"

// The publish target form asks for different things depending on the service:
// a Facebook page wants its ID, a YouTube channel wants a category, a URL of
// your own wants headers and a method. Rather than five forms, this hides
// what does not apply and relabels the one account field from the prompts the
// adapters declare.
export default class extends Controller {
  static targets = [
    "provider", "section", "accountGroup", "accountLabel", "accountHint", "privacyGroup", "privacy"
  ]
  static values = { prompts: Object, privacies: Object }

  connect() {
    this.refresh()
  }

  refresh() {
    const provider = this.providerTarget.value
    this.sectionTargets.forEach((section) => {
      const providers = (section.dataset.providers || "").split(" ").filter(Boolean)
      section.hidden = providers.length > 0 && !providers.includes(provider)
    })
    this.relabelAccount(this.promptsValue[provider])
    this.rebuildPrivacy(this.privaciesValue[provider] || {})
  }

  relabelAccount(prompt) {
    if (!this.hasAccountGroupTarget) return

    this.accountGroupTarget.hidden = !prompt
    if (!prompt) return

    this.accountLabelTarget.textContent = prompt.required ? `${prompt.label} (required)` : prompt.label
    this.accountHintTarget.textContent = prompt.hint || ""
  }

  // Rebuilt rather than filtered, because the choices are the provider's own
  // words for them — "Unlisted" means something different to Vimeo than it
  // does to TikTok. A value that survives the change is kept selected.
  rebuildPrivacy(options) {
    if (!this.hasPrivacyTarget) return

    const keys = Object.keys(options)
    this.privacyGroupTarget.hidden = keys.length === 0
    const chosen = this.privacyTarget.value
    this.privacyTarget.replaceChildren(new Option("Ask each time", ""))
    keys.forEach((key) => {
      this.privacyTarget.appendChild(new Option(options[key], key, false, key === chosen))
    })
  }
}

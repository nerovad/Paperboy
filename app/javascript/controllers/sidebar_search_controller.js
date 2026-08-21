// app/javascript/controllers/sidebar_search_controller.js
import { Controller } from "@hotwired/stimulus"

// The metadata a form link carries, in the order a match is preferred: the
// form's own name first, then its official number, its tags, its field labels
// and finally its description. `bonus` keeps that order even when a weaker
// source happens to score the tighter match, and `hint` is the label shown
// beside the form name to explain why a form is in the list at all when the
// match was not on its name.
const MATCH_SOURCES = [
  { key: "originalName", bonus: 50, multi: false, hint: null, hintClass: null },
  { key: "number", bonus: 40, multi: false, hint: "No.", hintClass: "matched-tag" },
  { key: "tags", bonus: 30, multi: true, hint: "Tag", hintClass: "matched-tag" },
  { key: "fields", bonus: 0, multi: true, hint: "Field", hintClass: "matched-field" },
  { key: "description", bonus: 0, multi: false, hint: null, hintClass: null }
]

export default class extends Controller {
  static targets = ["input", "formLink", "formsList", "item", "emptyState"]
  static values = { debounce: { type: Number, default: 0 } }

  connect() {
    this.filterTimer = null
    // Store original form names before any modifications
    // If data-original-name is already set (e.g. on complex cards), keep it
    this.formLinkTargets.forEach(link => {
      if (!link.dataset.originalName) {
        link.dataset.originalName = link.textContent.trim()
      }
    })
  }

  disconnect() {
    clearTimeout(this.filterTimer)
  }

  filter() {
    clearTimeout(this.filterTimer)
    if (this.debounceValue > 0) {
      this.filterTimer = setTimeout(() => this.performFilter(), this.debounceValue)
      return
    }

    this.performFilter()
  }

  performFilter() {
    if (this.hasItemTarget) {
      this.filterItems()
      return
    }

    const searchTerm = this.inputTarget.value.toLowerCase().trim()

    if (searchTerm === "") {
      // Show every link the facets still allow, remove highlighting, and
      // restore alphabetical order.
      const links = [...this.formLinkTargets]
      links.sort((a, b) => a.dataset.originalName.localeCompare(b.dataset.originalName))
      links.forEach(link => {
        link.style.display = this.facetHidden(link) ? "none" : ""
        if (!link.hasAttribute("data-search-card")) {
          link.innerHTML = link.dataset.originalName
        }
        this.formsListTarget.appendChild(link)
      })
      this.updateEmptyState()
      return
    }

    // Score every link against each of its metadata sources and keep its best
    // match. MATCH_SOURCES is in priority order, so a tie goes to the stronger
    // source and a name match still wins a field match of equal tightness.
    const scored = this.formLinkTargets.map(link => {
      let best = { score: 0, matches: [], hint: null, hintClass: null, matchedValue: null, isName: false }

      MATCH_SOURCES.forEach(source => {
        const raw = link.dataset[source.key] || ""
        if (!raw) return

        const candidates = source.multi ? raw.split(", ") : [raw]
        candidates.forEach(candidate => {
          const result = this.fuzzyMatch(searchTerm, candidate)
          if (result.score === 0) return

          const score = result.score + source.bonus
          if (score <= best.score) return

          best = {
            score,
            matches: result.matches,
            hint: source.hint,
            hintClass: source.hintClass,
            matchedValue: candidate,
            isName: source.key === "originalName"
          }
        })
      })

      return { link, formName: link.dataset.originalName, ...best }
    })

    // Sort by score (higher is better), then alphabetically
    scored.sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score
      return a.formName.localeCompare(b.formName)
    })

    // Reorder and display links
    scored.forEach(({ link, formName, matches, score, hint, hintClass, matchedValue, isName }) => {
      const isCard = link.hasAttribute("data-search-card")

      // A form the facets have excluded stays out however well its text
      // matches — Advanced Search is the narrower question, and a search
      // inside it should never reach back past it.
      if (score > 0 && !this.facetHidden(link)) {
        link.style.display = ""
        // Only modify innerHTML for simple link targets (sidebar), not complex cards
        if (!isCard) {
          if (isName) {
            link.innerHTML = this.highlightMatches(formName, matches)
          } else if (hint) {
            link.innerHTML = `${this.escapeHtml(formName)}<span class="${hintClass}">${hint}: ${this.escapeHtml(matchedValue)}</span>`
          } else {
            link.innerHTML = this.escapeHtml(formName)
          }
        }
      } else {
        link.style.display = "none"
        if (!isCard) {
          link.innerHTML = formName
        }
      }
      // Reorder in DOM
      this.formsListTarget.appendChild(link)
    })

    this.updateEmptyState()
  }

  // Whether Advanced Search has ruled this form out. Set by
  // advanced_search_controller.js; absent everywhere else, which reads as
  // "nothing has been ruled out".
  facetHidden(link) {
    return link.dataset.facetHidden === "true"
  }

  // Says so when the filters between them leave nothing, rather than leaving a
  // blank space that reads as a list that failed to load.
  updateEmptyState() {
    if (!this.hasEmptyStateTarget) return

    this.emptyStateTarget.hidden = this.formLinkTargets.some(link => link.style.display !== "none")
  }

  filterItems() {
    const query = this.inputTarget.value.toLowerCase().trim()
    const scored = this.itemTargets.map(item => ({ item, score: this.score(query, item.dataset.search) }))

    scored.sort((a, b) => b.score - a.score || a.item.dataset.search.localeCompare(b.item.dataset.search))
    scored.forEach(({ item, score }) => {
      item.hidden = query !== "" && score === 0
      item.parentElement.appendChild(item)
    })
  }

  score(pattern, text) {
    if (pattern === "") return 1

    let at = 0
    let score = 0
    let previous = -2
    const value = text.toLowerCase()

    for (let index = 0; index < value.length && at < pattern.length; index += 1) {
      if (value[index] !== pattern[at]) continue

      score += index === previous + 1 ? 8 : 2
      score += index === 0 || " _-/".includes(value[index - 1]) ? 10 : 0
      previous = index
      at += 1
    }

    return at === pattern.length ? score + 100 : 0
  }

  fuzzyMatch(pattern, text) {
    const lowerPattern = pattern.toLowerCase()
    const lowerText = text.toLowerCase()
    const matches = []
    let patternIdx = 0
    let score = 0
    let consecutiveBonus = 0

    for (let i = 0; i < text.length && patternIdx < pattern.length; i++) {
      if (lowerText[i] === lowerPattern[patternIdx]) {
        matches.push(i)

        // Scoring: bonus for consecutive matches
        if (matches.length > 1 && matches[matches.length - 2] === i - 1) {
          consecutiveBonus += 5
        }

        // Bonus for matching at word boundary
        if (i === 0 || text[i - 1] === ' ' || text[i - 1] === '-' || text[i - 1] === '_') {
          score += 10
        }

        patternIdx++
      }
    }

    // All pattern characters must match
    if (patternIdx === pattern.length) {
      score += 100 + consecutiveBonus
      // Bonus for shorter strings (tighter match)
      score += Math.max(0, 50 - text.length)
    } else {
      score = 0
    }

    return { matches, score }
  }

  highlightMatches(text, matches) {
    if (!matches || matches.length === 0) return text

    let result = ''
    let lastIdx = 0

    matches.forEach(idx => {
      result += this.escapeHtml(text.slice(lastIdx, idx))
      result += `<mark>${this.escapeHtml(text[idx])}</mark>`
      lastIdx = idx + 1
    })

    result += this.escapeHtml(text.slice(lastIdx))
    return result
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}

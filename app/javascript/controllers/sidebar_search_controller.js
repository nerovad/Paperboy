// app/javascript/controllers/sidebar_search_controller.js
import { Controller } from "@hotwired/stimulus"

// The metadata a row carries, in the order a match is preferred: the row's own
// name first, then a form's official number, its tags, the app a destination
// belongs to, the words a destination answers to besides its name, and finally
// a form's field labels and description. `bonus` keeps that order even when a
// weaker source happens to score the tighter match, and `hint` is the label
// shown beside the name to explain why a row is in the list at all when the
// match was not on its name.
//
// Forms carry number/tags/fields/description; destinations carry
// context/keywords. Each simply skips the sources it has none of.
const MATCH_SOURCES = [
  { key: "originalName", bonus: 50, multi: false, hint: null, hintClass: null },
  { key: "number", bonus: 40, multi: false, hint: "No.", hintClass: "matched-tag" },
  { key: "tags", bonus: 30, multi: true, hint: "Tag", hintClass: "matched-tag" },
  // The app a destination is in is already printed on the row, so a match on
  // it needs no hint — typing "billing" should just list Billing's screens.
  { key: "context", bonus: 25, multi: false, hint: null, hintClass: null },
  { key: "keywords", bonus: 20, multi: false, hint: null, hintClass: null },
  { key: "fields", bonus: 0, multi: true, hint: "Field", hintClass: "matched-field" },
  { key: "description", bonus: 0, multi: false, hint: null, hintClass: null }
]

export default class extends Controller {
  static targets = ["input", "formLink", "formsList", "destination", "destinationsList", "item", "emptyState", "command"]
  static values = { debounce: { type: Number, default: 0 } }

  connect() {
    this.filterTimer = null
    // Store original names before any modifications. If data-original-name is
    // already set — on complex cards, and on the palette's destinations, whose
    // markup includes the app label — keep it.
    this.rows().forEach(row => {
      if (!row.dataset.originalName) {
        row.dataset.originalName = row.textContent.trim()
      }
    })
  }

  disconnect() {
    clearTimeout(this.filterTimer)
  }

  // Every row this controller ranks, whichever list it lives in.
  rows() {
    return [...this.formLinkTargets, ...this.destinationTargets]
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
    const searchTerm = this.inputTarget.value.toLowerCase().trim()
    this.filterCommands(searchTerm)

    if (this.hasItemTarget) {
      this.filterItems()
      return
    }

    // Each list is ranked against the query on its own, so a destination is
    // never sorted in among the forms. Destinations keep their declared order
    // when nothing is typed — they are grouped by app, which is more use than
    // one alphabetical run of every screen in the system.
    this.rankList(searchTerm, this.formLinkTargets, this.formsListTarget, true)
    if (this.hasDestinationTarget) {
      this.rankList(searchTerm, this.destinationTargets, this.destinationsListTarget, false)
    }

    this.updateEmptyState()
  }

  // Score every row against each of its metadata sources and keep its best
  // match, then reorder the list best-first. MATCH_SOURCES is in priority
  // order, so a tie goes to the stronger source and a name match still wins a
  // field match of equal tightness.
  rankList(searchTerm, rows, list, sortWhenEmpty) {
    if (searchTerm === "") {
      const ordered = sortWhenEmpty
        ? [...rows].sort((a, b) => a.dataset.originalName.localeCompare(b.dataset.originalName))
        : rows

      ordered.forEach(row => {
        row.style.display = this.facetHidden(row) ? "none" : ""
        this.renderRow(row, { matched: false })
        list.appendChild(row)
      })
      this.markListEmpty(list, rows)
      return
    }

    const scored = rows.map(row => ({ row, ...this.bestMatch(searchTerm, row) }))

    scored.sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score
      return a.row.dataset.originalName.localeCompare(b.row.dataset.originalName)
    })

    scored.forEach(({ row, score, ...match }) => {
      // A form the facets have excluded stays out however well its text
      // matches — Advanced Search is the narrower question, and a search
      // inside it should never reach back past it.
      const visible = score > 0 && !this.facetHidden(row)
      row.style.display = visible ? "" : "none"
      this.renderRow(row, { ...match, matched: visible })
      list.appendChild(row)
    })

    this.markListEmpty(list, rows)
  }

  bestMatch(searchTerm, row) {
    let best = { score: 0, matches: [], hint: null, hintClass: null, matchedValue: null, isName: false }

    MATCH_SOURCES.forEach(source => {
      const raw = row.dataset[source.key] || ""
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

    return best
  }

  // A row reads: the app it belongs to (destinations only), its name with the
  // typed letters marked, and — when the match was not on the name — what it
  // did match. Cards render their own contents and are left alone.
  renderRow(row, { matched, matches, hint, hintClass, matchedValue, isName }) {
    if (row.hasAttribute("data-search-card")) return

    const name = row.dataset.originalName
    const context = row.dataset.context
      ? `<span class="search-context">${this.escapeHtml(row.dataset.context)}</span>`
      : ""
    const body = matched && isName ? this.highlightMatches(name, matches) : this.escapeHtml(name)
    const why = matched && !isName && hint
      ? `<span class="${hintClass}">${hint}: ${this.escapeHtml(matchedValue)}</span>`
      : ""

    row.innerHTML = context + body + why
  }

  // A list whose rows have all been filtered out hides itself, heading and
  // all, rather than leaving "Go to" standing over nothing. A list that holds
  // the empty-state message is left alone — it says so itself, and hiding it
  // would take the message with it.
  markListEmpty(list, rows) {
    if (this.hasEmptyStateTarget && list.contains(this.emptyStateTarget)) return

    list.hidden = !rows.some(row => row.style.display !== "none")
  }

  // Commands are what the sidebar can *do* rather than what it can open —
  // "who am i" today, anything added beside it later. They are offered only
  // once something has been typed, so an untouched sidebar stays a plain list
  // of forms, and they sit above that list because a command answers the whole
  // question typed rather than matching one form's metadata.
  filterCommands(searchTerm) {
    if (!this.hasCommandTarget) return

    this.commandTargets.forEach(command => {
      command.hidden = searchTerm === "" || !this.commandMatches(searchTerm, command.dataset.search)
    })
  }

  // Every word typed has to start a word the command answers to. Deliberately
  // stricter than the fuzzy match used on forms: a command is offered above
  // everything else, so "hi" must not summon "Who Am I" on its way to a form.
  commandMatches(searchTerm, terms) {
    const words = terms.toLowerCase().split(/\s+/)

    return searchTerm.split(/\s+/).every(token => words.some(word => word.startsWith(token)))
  }

  // Enter runs the command on offer, so asking is one typed phrase and no
  // reach for the mouse. With nothing matching it does nothing — the form
  // links are ordinary navigation, and Enter has never opened them.
  activate(event) {
    if (!this.hasCommandTarget) return

    const command = this.commandTargets.find(candidate => !candidate.hidden)
    if (!command) return

    event.preventDefault()
    command.click()
  }

  // Whether Advanced Search has ruled this form out. Set by
  // advanced_search_controller.js; absent everywhere else, which reads as
  // "nothing has been ruled out".
  facetHidden(row) {
    return row.dataset.facetHidden === "true"
  }

  // Says so when the filters between them leave nothing, rather than leaving a
  // blank space that reads as a list that failed to load.
  updateEmptyState() {
    if (!this.hasEmptyStateTarget) return

    const commandOffered = this.hasCommandTarget && this.commandTargets.some(command => !command.hidden)

    this.emptyStateTarget.hidden = commandOffered ||
      this.rows().some(row => row.style.display !== "none")
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

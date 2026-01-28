// app/javascript/controllers/sidebar_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "formLink", "formsList"]

  connect() {
    // Store original form names before any modifications
    this.formLinkTargets.forEach(link => {
      link.dataset.originalName = link.textContent.trim()
    })
  }

  filter() {
    const searchTerm = this.inputTarget.value.toLowerCase().trim()

    if (searchTerm === "") {
      // Show all links in original order, remove highlighting
      this.formLinkTargets.forEach(link => {
        link.style.display = ""
        link.innerHTML = link.dataset.originalName
      })
      return
    }

    // Score and filter links (search form name, field labels, and tags)
    const scored = this.formLinkTargets.map(link => {
      const formName = link.dataset.originalName
      const fields = link.dataset.fields || ""
      const tags = link.dataset.tags || ""

      // Match against form name
      const nameResult = this.fuzzyMatch(searchTerm, formName)

      // Match against field labels (search each field separately)
      let bestFieldMatch = { matches: [], score: 0, fieldName: null }
      if (fields) {
        const fieldList = fields.split(", ")
        for (const field of fieldList) {
          const fieldResult = this.fuzzyMatch(searchTerm, field)
          if (fieldResult.score > bestFieldMatch.score) {
            bestFieldMatch = { ...fieldResult, fieldName: field }
          }
        }
      }

      // Match against tags (search each tag separately)
      let bestTagMatch = { matches: [], score: 0, tagName: null }
      if (tags) {
        const tagList = tags.split(", ")
        for (const tag of tagList) {
          const tagResult = this.fuzzyMatch(searchTerm, tag)
          if (tagResult.score > bestTagMatch.score) {
            bestTagMatch = { ...tagResult, tagName: tag }
          }
        }
      }

      // Use the better match (name match gets priority bonus, then tags, then fields)
      const nameScore = nameResult.score > 0 ? nameResult.score + 50 : 0
      const tagScore = bestTagMatch.score > 0 ? bestTagMatch.score + 30 : 0
      const fieldScore = bestFieldMatch.score

      if (nameScore >= tagScore && nameScore >= fieldScore) {
        return { link, formName, ...nameResult, matchedField: null, matchedTag: null }
      } else if (tagScore >= fieldScore) {
        return { link, formName, matches: [], score: tagScore, matchedField: null, matchedTag: bestTagMatch.tagName }
      } else {
        return { link, formName, matches: [], score: fieldScore, matchedField: bestFieldMatch.fieldName, matchedTag: null }
      }
    })

    // Sort by score (higher is better), then alphabetically
    scored.sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score
      return a.formName.localeCompare(b.formName)
    })

    // Reorder and display links
    scored.forEach(({ link, formName, matches, score, matchedField, matchedTag }) => {
      if (score > 0) {
        link.style.display = ""
        if (matchedTag) {
          // Match was in a tag - show tag below form name
          link.innerHTML = `${this.escapeHtml(formName)}<span class="matched-tag">Tag: ${this.escapeHtml(matchedTag)}</span>`
        } else if (matchedField) {
          // Match was in a field - show field name below form name
          link.innerHTML = `${this.escapeHtml(formName)}<span class="matched-field">Field: ${this.escapeHtml(matchedField)}</span>`
        } else {
          // Match was in form name - highlight matches
          link.innerHTML = this.highlightMatches(formName, matches)
        }
      } else {
        link.style.display = "none"
        link.innerHTML = formName
      }
      // Reorder in DOM
      this.formsListTarget.appendChild(link)
    })
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

import { Controller } from "@hotwired/stimulus"

const tokenPattern = /(#.*$|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b(?:alias|and|begin|break|case|class|def|defined|do|else|elsif|end|ensure|false|for|if|in|module|next|nil|not|or|redo|rescue|retry|return|self|super|then|true|undef|unless|until|when|while|yield)\b|:[a-zA-Z_]\w*[!?=]?|\b[A-Z]\w*\b|\b\d+(?:\.\d+)?\b|[{}\[\](),.=+\-*\/<>!&|]+)/gm

export default class extends Controller {
  static targets = ["highlight", "input"]

  connect() {
    this.update()
    this.syncScroll()
  }

  update() {
    this.highlightTarget.innerHTML = `${this.highlight(this.inputTarget.value)}\n`
    this.syncScroll()
  }

  syncScroll() {
    this.highlightTarget.scrollLeft = this.inputTarget.scrollLeft
    this.highlightTarget.scrollTop = this.inputTarget.scrollTop
  }

  highlight(source) {
    let html = ""
    let index = 0

    source.replace(tokenPattern, (token, _match, offset) => {
      html += this.escape(source.slice(index, offset))
      html += this.wrap(token)
      index = offset + token.length
      return token
    })

    return html + this.escape(source.slice(index))
  }

  wrap(token) {
    return `<span class="${this.tokenClass(token)}">${this.escape(token)}</span>`
  }

  tokenClass(token) {
    if (token.startsWith("#")) return "c1"
    if (token.startsWith("\"") || token.startsWith("'")) return "s"
    if (token.startsWith(":")) return "ss"
    if (/^\d/.test(token)) return "mi"
    if (/^[A-Z]/.test(token)) return "nc"
    if (/^[{}\[\](),.=+\-*\/<>!&|]+$/.test(token)) return "o"
    return "k"
  }

  escape(value) {
    return value
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
  }
}

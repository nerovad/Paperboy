// Small helpers more than one AIM controller needs. Not a controller: nothing
// registers it, the controllers import it by name (the importmap pins every
// file under controllers/).

// The page's CSRF token, for a fetch or a beacon.
export function csrfToken() {
  return document.querySelector("meta[name=csrf-token]")?.content || ""
}

// The budget units a person works in, read off the grouped person <select>:
// they are listed under one optgroup (data-unit) per BU they belong to.
export function unitsOf(personSelect, id) {
  return Array.from(personSelect.querySelectorAll("optgroup"))
    .filter((group) => group.dataset.unit && group.querySelector(`option[value="${id}"]`))
    .map((group) => group.dataset.unit)
}

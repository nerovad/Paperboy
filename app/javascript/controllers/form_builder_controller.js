import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "formName",
    "accessLevel",
    "aclGroup",
    "aclGroupContainer",
    "pageCount",
    "pageHeadersContainer",
    "pageHeadersList",
    "fieldsContainer",
    "fieldItem",
    "submitButton"
  ]

  static values = {
    aclGroups: Array
  }

  connect() {
    console.log("Form builder controller connected")
    this.fieldCounter = 0
  }

  openModal() {
    const modal = document.getElementById('create-form-modal')
    if (modal) {
      modal.style.display = 'flex'
      document.body.style.overflow = 'hidden'
    }
  }

  closeModal() {
    const modal = document.getElementById('create-form-modal')
    if (modal) {
      modal.style.display = 'none'
      document.body.style.overflow = 'auto'
      this.resetForm()
    }
  }

  resetForm() {
    this.formTarget.reset()
    this.fieldsContainerTarget.innerHTML = ''
    this.aclGroupContainerTarget.style.display = 'none'
    this.pageHeadersContainerTarget.style.display = 'none'
    this.fieldCounter = 0
  }

  toggleACLGroup(event) {
    const isRestricted = event.target.value === 'restricted'
    this.aclGroupContainerTarget.style.display = isRestricted ? 'block' : 'none'

    if (!isRestricted) {
      this.aclGroupTarget.value = ''
    }
  }

  updatePageHeaders(event) {
    const pageCount = parseInt(event.target.value)

    if (pageCount > 2) {
      this.pageHeadersContainerTarget.style.display = 'block'
      this.renderPageHeaderInputs(pageCount)
    } else {
      this.pageHeadersContainerTarget.style.display = 'none'
      this.pageHeadersListTarget.innerHTML = ''
    }

    // Update all page select dropdowns in fields
    this.updatePageSelects(pageCount)
  }

  renderPageHeaderInputs(pageCount) {
    const additionalPages = pageCount - 2
    let html = ''

    for (let i = 1; i <= additionalPages; i++) {
      const pageNum = i + 2
      html += `
        <div class="form-group-inline">
          <label>Page ${pageNum}:</label>
          <input type="text" 
                 name="form_template[page_headers][]" 
                 class="form-control form-control-sm"
                 placeholder="e.g., Additional Information"
                 required>
        </div>
      `
    }

    this.pageHeadersListTarget.innerHTML = html
  }

  updatePageSelects(pageCount) {
    const pageSelects = this.fieldsContainerTarget.querySelectorAll('.page-select')

    pageSelects.forEach(select => {
      const currentValue = select.value
      let options = `
        <option value="1">Page 1 - Employee Info</option>
        <option value="2">Page 2 - Agency Info</option>
      `

      for (let i = 3; i <= pageCount; i++) {
        options += `<option value="${i}">Page ${i}</option>`
      }

      select.innerHTML = options

      // Restore previous selection if still valid
      if (currentValue && currentValue <= pageCount) {
        select.value = currentValue
      }
    })
  }

  addField(event) {
    event.preventDefault()

    const template = document.getElementById('field-template')
    const clone = template.content.cloneNode(true)

    this.fieldsContainerTarget.appendChild(clone)

    // Update the page select for this new field
    const pageCount = parseInt(this.pageCountTarget.value)
    this.updatePageSelects(pageCount)

    this.fieldCounter++
  }

  removeField(event) {
    event.preventDefault()
    const fieldItem = event.target.closest('.field-item')
    if (fieldItem) {
      fieldItem.remove()
    }
  }

  handleFieldTypeChange(event) {
    const fieldItem = event.target.closest('.field-item')
    const fieldType = event.target.value

    // Hide all options first
    const allOptions = fieldItem.querySelectorAll('.field-options')
    allOptions.forEach(opt => opt.style.display = 'none')

    // Show relevant options
    if (fieldType === 'text_box') {
      const textBoxOptions = fieldItem.querySelector('.text-box-options')
      if (textBoxOptions) textBoxOptions.style.display = 'block'
    } else if (fieldType === 'dropdown') {
      const dropdownOptions = fieldItem.querySelector('.dropdown-options')
      if (dropdownOptions) dropdownOptions.style.display = 'block'
    }
  }

  submitForm(event) {
    event.preventDefault()

    // Disable submit button to prevent double submission
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = 'Creating...'

    const formData = new FormData(this.formTarget)

    fetch(this.formTarget.action, {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'application/json'
      }
    })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          alert(data.message)
          this.closeModal()

          if (data.redirect) {
            window.location.href = data.redirect
          } else {
            window.location.reload()
          }
        } else {
          alert('Error creating form:\n' + data.errors.join('\n'))
          this.submitButtonTarget.disabled = false
          this.submitButtonTarget.textContent = 'Create Form Template'
        }
      })
      .catch(error => {
        console.error('Error:', error)
        alert('An error occurred while creating the form.')
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.textContent = 'Create Form Template'
      })
  }
}

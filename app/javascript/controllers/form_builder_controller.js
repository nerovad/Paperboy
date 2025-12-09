// form_builder_controller.js - Updates needed for improved modal scrolling

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
    console.log("Form Builder controller connected")
    // Add one field by default
    this.addField()
  }

  // Show the modal
  openModal(event) {
    event.preventDefault()
    const modal = document.getElementById('create-form-modal')
    if (modal) {
      // Use the 'show' class to display with flexbox
      modal.classList.add('show')
      modal.style.display = 'flex'

      // Lock body scroll when modal is open
      document.body.style.overflow = 'hidden'
    }
  }

  // Close the modal
  closeModal(event) {
    event.preventDefault()
    const modal = document.getElementById('create-form-modal')
    if (modal) {
      modal.classList.remove('show')
      modal.style.display = 'none'

      // Restore body scroll
      document.body.style.overflow = 'auto'

      // Reset form
      this.formTarget.reset()
      this.fieldsContainerTarget.innerHTML = ''
      this.addField() // Add back the default field
      this.pageHeadersContainerTarget.style.display = 'none'
      this.aclGroupContainerTarget.style.display = 'none'
    }
  }

  // Close modal when clicking outside the modal content
  clickOutside(event) {
    if (event.target.id === 'create-form-modal') {
      this.closeModal(event)
    }
  }

  // Toggle ACL Group visibility based on access level
  toggleACLGroup(event) {
    const accessLevel = event.target.value
    const container = this.aclGroupContainerTarget

    if (accessLevel === 'restricted') {
      container.style.display = 'block'
      this.aclGroupTarget.required = true
    } else {
      container.style.display = 'none'
      this.aclGroupTarget.required = false
      this.aclGroupTarget.value = ''
    }
  }

  // Update page headers based on page count
  updatePageHeaders(event) {
    const pageCount = parseInt(event.target.value)
    const container = this.pageHeadersContainerTarget
    const headersList = this.pageHeadersListTarget

    if (pageCount > 2) {
      container.style.display = 'block'
      headersList.innerHTML = ''

      // Create input fields for pages 3+
      for (let i = 3; i <= pageCount; i++) {
        const headerItem = document.createElement('div')
        headerItem.className = 'page-header-item'
        headerItem.innerHTML = `
          <label>Page ${i}:</label>
          <input type="text" 
                 name="page_headers[]" 
                 class="form-control form-control-sm"
                 placeholder="e.g., Additional Information"
                 required>
        `
        headersList.appendChild(headerItem)
      }

      // Update all page selects to include new pages
      this.updatePageSelects(pageCount)
    } else {
      container.style.display = 'none'
      headersList.innerHTML = ''
      this.updatePageSelects(2) // Reset to just 2 pages
    }
  }

  // Update all page select dropdowns with current page count
  updatePageSelects(pageCount) {
    const pageSelects = this.fieldsContainerTarget.querySelectorAll('.page-select')
    const templateSelect = document.querySelector('#field-template .page-select')

    // Update existing field page selects
    pageSelects.forEach(select => {
      const currentValue = select.value
      select.innerHTML = this.generatePageOptions(pageCount)
      if (currentValue && parseInt(currentValue) <= pageCount) {
        select.value = currentValue
      }
    })

    // Update template page select
    if (templateSelect) {
      templateSelect.innerHTML = this.generatePageOptions(pageCount)
    }
  }

  // Generate page options HTML
  generatePageOptions(pageCount) {
    let options = `
      <option value="1">Page 1 - Employee Info</option>
      <option value="2">Page 2 - Agency Info</option>
    `

    for (let i = 3; i <= pageCount; i++) {
      const input = this.pageHeadersListTarget?.querySelector(`input:nth-child(${i - 2})`)
      const pageName = input?.value || `Page ${i}`
      options += `<option value="${i}">Page ${i} - ${pageName}</option>`
    }

    return options
  }

  // Add a new field
  addField(event) {
    if (event) event.preventDefault()

    const template = document.getElementById('field-template')
    const clone = template.content.cloneNode(true)

    // Update page select options if needed
    const pageCount = parseInt(this.pageCountTarget.value)
    const pageSelect = clone.querySelector('.page-select')
    if (pageSelect) {
      pageSelect.innerHTML = this.generatePageOptions(pageCount)
    }

    this.fieldsContainerTarget.appendChild(clone)
  }

  // Remove a field
  removeField(event) {
    event.preventDefault()
    const fieldItem = event.target.closest('.field-item')
    if (fieldItem) {
      fieldItem.remove()
    }
  }

  // Handle field type change to show/hide options
  handleFieldTypeChange(event) {
    const fieldItem = event.target.closest('.field-item')
    const fieldType = event.target.value
    const textBoxOptions = fieldItem.querySelector('.text-box-options')
    const dropdownOptions = fieldItem.querySelector('.dropdown-options')

    // Hide all options first
    textBoxOptions.style.display = 'none'
    dropdownOptions.style.display = 'none'

    // Show relevant options
    if (fieldType === 'text_box') {
      textBoxOptions.style.display = 'block'
    } else if (fieldType === 'dropdown') {
      dropdownOptions.style.display = 'block'
    }
  }

  // Submit form
  submitForm(event) {
    // Let form submit naturally
    console.log("Form submitting...")
  }
}

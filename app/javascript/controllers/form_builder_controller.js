// form_builder_controller.js - Updates needed for improved modal scrolling

import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

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
    "submitButton",
    "submissionType",
    "approvalRoutingContainer",
    "routingStepsContainer",
    "routingStepItem"
  ]

  static values = {
    aclGroups: Array,
    employees: Array
  }

  connect() {
    console.log("Form Builder controller connected")
    // Add one field by default only if we're in the create modal
    const template = document.getElementById('field-template')
    if (template) {
      this.addField()
    }

    // Initialize sortable on fields container
    this.initializeSortable()
  }

  // Initialize SortableJS for drag-and-drop field reordering
  initializeSortable() {
    if (this.hasFieldsContainerTarget) {
      this.sortable = new Sortable(this.fieldsContainerTarget, {
        animation: 150,
        handle: '.drag-handle',
        ghostClass: 'field-item-ghost',
        chosenClass: 'field-item-chosen',
        dragClass: 'field-item-drag',
        onEnd: () => {
          this.updateFieldPositions()
        }
      })
    }
  }

  // Update visual position indicators after reorder
  updateFieldPositions() {
    const fields = this.fieldsContainerTarget.querySelectorAll('.field-item')
    fields.forEach((field, index) => {
      const positionLabel = field.querySelector('.field-position')
      if (positionLabel) {
        positionLabel.textContent = `#${index + 1}`
      }
    })
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
      this.approvalRoutingContainerTarget.style.display = 'none'
      this.routingStepsContainerTarget.innerHTML = ''
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

  // Toggle approval routing options based on submission type
  toggleApprovalRouting(event) {
    const submissionType = event.target.value
    const container = this.approvalRoutingContainerTarget

    if (submissionType === 'approval') {
      container.style.display = 'block'
      // Add a default routing step if none exist
      if (this.routingStepItemTargets.length === 0) {
        this.addRoutingStep()
      }
    } else {
      container.style.display = 'none'
      // Clear all routing steps
      this.routingStepsContainerTarget.innerHTML = ''
    }
  }

  // Add a new routing step
  addRoutingStep(event) {
    if (event) event.preventDefault()

    const template = document.getElementById('routing-step-template')
    if (!template) {
      console.error('Routing step template not found')
      return
    }

    const clone = template.content.cloneNode(true)

    // Update step number
    const stepNumber = this.routingStepItemTargets.length + 1
    const stepLabel = clone.querySelector('.step-number')
    if (stepLabel) {
      stepLabel.textContent = `Step ${stepNumber}:`
    }

    const stepInput = clone.querySelector('.step-number-input')
    if (stepInput) {
      stepInput.value = stepNumber
    }

    // Populate employee dropdown
    const employeeSelect = clone.querySelector('.step-employee-dropdown')
    if (employeeSelect && this.employeesValue) {
      this.employeesValue.forEach(emp => {
        const option = document.createElement('option')
        option.value = emp[1]  // EmployeeID
        option.textContent = emp[0]  // "First Last (EmployeeID)"
        employeeSelect.appendChild(option)
      })
    }

    this.routingStepsContainerTarget.appendChild(clone)
  }

  // Remove a routing step
  removeRoutingStep(event) {
    event.preventDefault()
    const stepItem = event.target.closest('.routing-step-item')
    if (stepItem) {
      stepItem.remove()
      // Renumber remaining steps
      this.renumberRoutingSteps()
    }
  }

  // Renumber routing steps after removal
  renumberRoutingSteps() {
    this.routingStepItemTargets.forEach((item, index) => {
      const stepNumber = index + 1
      const stepLabel = item.querySelector('.step-number')
      if (stepLabel) {
        stepLabel.textContent = `Step ${stepNumber}:`
      }
      const stepInput = item.querySelector('.step-number-input')
      if (stepInput) {
        stepInput.value = stepNumber
      }
    })
  }

  // Toggle employee select for a specific routing step
  toggleStepEmployeeSelect(event) {
    const routingType = event.target.value
    const stepItem = event.target.closest('.routing-step-item')
    const employeeSelectContainer = stepItem.querySelector('.step-employee-select')
    const employeeSelect = stepItem.querySelector('.step-employee-dropdown')

    if (routingType === 'employee') {
      employeeSelectContainer.style.display = 'block'
      employeeSelect.required = true
    } else {
      employeeSelectContainer.style.display = 'none'
      employeeSelect.required = false
      employeeSelect.value = ''
    }
  }

  // Toggle Power BI fields visibility based on has_dashboard selection
  togglePowerBIFields(event) {
    const hasDashboard = event.target.value === 'true'
    const powerbiFields = document.getElementById('powerbi-fields')

    if (powerbiFields) {
      powerbiFields.style.display = hasDashboard ? 'block' : 'none'
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
                name="form_template[page_headers][]" 
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
  // Generate page options HTML
  generatePageOptions(pageCount) {
    let options = `
      <option value="1">Page 1 - Employee Info</option>
      <option value="2">Page 2 - Agency Info</option>
    `

    for (let i = 3; i <= pageCount; i++) {
      // Get all page header inputs, then grab the one for this page
      const allInputs = this.pageHeadersListTarget?.querySelectorAll('input')
      const input = allInputs?.[i - 3] // Array index: page 3 = index 0, page 4 = index 1, etc.
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

    // Populate restriction dropdowns for the newly added field
    const addedField = this.fieldsContainerTarget.lastElementChild
    if (addedField) {
      this.populateRestrictionDropdowns(addedField)
    }

    // Update position indicators
    this.updateFieldPositions()
  }

  // Remove a field
  removeField(event) {
    event.preventDefault()
    const fieldItem = event.target.closest('.field-item')
    if (fieldItem) {
      fieldItem.remove()
      // Update position indicators
      this.updateFieldPositions()
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

    // Refresh conditional dropdowns in other fields (they may now see this as a dropdown option)
    this.refreshConditionalDropdowns()
  }

  // Toggle field restriction dropdowns based on restriction type
  toggleFieldRestriction(event) {
    const fieldItem = event.target.closest('.field-item')
    const restrictionType = event.target.value
    const employeeContainer = fieldItem.querySelector('.restriction-employee-select')
    const groupContainer = fieldItem.querySelector('.restriction-group-select')
    const employeeSelect = fieldItem.querySelector('.restriction-employee-dropdown')
    const groupSelect = fieldItem.querySelector('.restriction-group-dropdown')

    // Hide all restriction selects first
    employeeContainer.style.display = 'none'
    groupContainer.style.display = 'none'

    // Clear required attributes
    if (employeeSelect) employeeSelect.required = false
    if (groupSelect) groupSelect.required = false

    // Show relevant restriction select
    if (restrictionType === 'employee') {
      employeeContainer.style.display = 'inline-block'
      if (employeeSelect) employeeSelect.required = true
    } else if (restrictionType === 'group') {
      groupContainer.style.display = 'inline-block'
      if (groupSelect) groupSelect.required = true
    }
  }

  // Populate restriction dropdowns in a field item
  populateRestrictionDropdowns(fieldItem) {
    const employeeSelect = fieldItem.querySelector('.restriction-employee-dropdown')
    const groupSelect = fieldItem.querySelector('.restriction-group-dropdown')

    // Populate employee dropdown
    if (employeeSelect && this.employeesValue) {
      // Keep the placeholder option
      employeeSelect.innerHTML = '<option value="">Select employee...</option>'
      this.employeesValue.forEach(emp => {
        const option = document.createElement('option')
        option.value = emp[1]  // EmployeeID
        option.textContent = emp[0]  // "First Last (EmployeeID)"
        employeeSelect.appendChild(option)
      })
    }

    // Populate group dropdown
    if (groupSelect && this.aclGroupsValue) {
      // Keep the placeholder option
      groupSelect.innerHTML = '<option value="">Select group...</option>'
      this.aclGroupsValue.forEach(group => {
        const option = document.createElement('option')
        option.value = group[1]  // GroupID
        option.textContent = group[0]  // Group name
        groupSelect.appendChild(option)
      })
    }
  }

  // Toggle conditional options visibility
  toggleConditionalOptions(event) {
    const fieldItem = event.target.closest('.field-item')
    const conditionalConfig = fieldItem.querySelector('.conditional-config')
    const isChecked = event.target.checked

    if (conditionalConfig) {
      conditionalConfig.style.display = isChecked ? 'block' : 'none'

      // If enabling, update the dropdown options
      if (isChecked) {
        this.updateConditionalFieldDropdown(fieldItem)
      } else {
        // Clear conditional field selection when unchecked
        const conditionalSelect = fieldItem.querySelector('.conditional-field-select')
        if (conditionalSelect) conditionalSelect.value = ''
        const valuesContainer = fieldItem.querySelector('.conditional-values-container')
        if (valuesContainer) {
          valuesContainer.innerHTML = '<span style="font-size: 0.8em; color: #6c757d; font-style: italic;">Select a dropdown field first</span>'
        }
      }
    }
  }

  // Update the conditional field dropdown with available dropdown fields
  updateConditionalFieldDropdown(fieldItem) {
    const conditionalSelect = fieldItem.querySelector('.conditional-field-select')
    if (!conditionalSelect) return

    // Get all dropdown fields from the form
    const allFields = this.fieldsContainerTarget.querySelectorAll('.field-item')
    const currentFieldIndex = Array.from(allFields).indexOf(fieldItem)

    // Clear and rebuild options
    conditionalSelect.innerHTML = '<option value="">Select dropdown...</option>'

    allFields.forEach((field, index) => {
      // Skip the current field
      if (index === currentFieldIndex) return

      const typeSelect = field.querySelector('select[name="fields[][field_type]"]')
      const labelInput = field.querySelector('input[name="fields[][label]"]')
      const dropdownValuesInput = field.querySelector('input[name="fields[][dropdown_values]"]')

      // Only include dropdown fields
      if (typeSelect && typeSelect.value === 'dropdown' && labelInput) {
        const option = document.createElement('option')
        option.value = `field_${index}` // Use index as identifier
        option.textContent = labelInput.value || `Field ${index + 1}`
        option.dataset.fieldIndex = index

        // Store dropdown values if available
        if (dropdownValuesInput && dropdownValuesInput.value) {
          option.dataset.values = JSON.stringify(
            dropdownValuesInput.value.split(',').map(v => v.trim()).filter(v => v)
          )
        }

        conditionalSelect.appendChild(option)
      }
    })
  }

  // Update conditional values checkboxes when a dropdown is selected
  updateConditionalValues(event) {
    const fieldItem = event.target.closest('.field-item')
    const valuesContainer = fieldItem.querySelector('.conditional-values-container')
    const selectedOption = event.target.selectedOptions[0]

    if (!valuesContainer) return

    // Clear existing checkboxes
    valuesContainer.innerHTML = ''

    if (!selectedOption || !selectedOption.value) {
      valuesContainer.innerHTML = '<span style="font-size: 0.8em; color: #6c757d; font-style: italic;">Select a dropdown field first</span>'
      return
    }

    // Get values from the selected dropdown field
    let values = []

    // Check if values are stored in data attribute
    if (selectedOption.dataset.values) {
      try {
        values = JSON.parse(selectedOption.dataset.values)
      } catch (e) {
        console.error('Error parsing dropdown values:', e)
      }
    }

    // If using field index, get values from the actual field
    if (selectedOption.dataset.fieldIndex !== undefined) {
      const allFields = this.fieldsContainerTarget.querySelectorAll('.field-item')
      const targetField = allFields[parseInt(selectedOption.dataset.fieldIndex)]
      if (targetField) {
        const dropdownValuesInput = targetField.querySelector('input[name="fields[][dropdown_values]"]')
        if (dropdownValuesInput && dropdownValuesInput.value) {
          values = dropdownValuesInput.value.split(',').map(v => v.trim()).filter(v => v)
        }
      }
    }

    if (values.length === 0) {
      valuesContainer.innerHTML = '<span style="font-size: 0.8em; color: #6c757d; font-style: italic;">No values defined for this dropdown</span>'
      return
    }

    // Create checkboxes for each value
    values.forEach(value => {
      const label = document.createElement('label')
      label.style.cssText = 'font-size: 0.8em; display: flex; align-items: center; gap: 4px; background: #fff; padding: 4px 8px; border-radius: 4px; border: 1px solid #ddd;'

      const checkbox = document.createElement('input')
      checkbox.type = 'checkbox'
      checkbox.name = 'fields[][conditional_values][]'
      checkbox.value = value

      label.appendChild(checkbox)
      label.appendChild(document.createTextNode(value))
      valuesContainer.appendChild(label)
    })
  }

  // Refresh all conditional dropdowns when field types change
  refreshConditionalDropdowns() {
    const allFields = this.fieldsContainerTarget.querySelectorAll('.field-item')
    allFields.forEach(field => {
      const conditionalToggle = field.querySelector('.conditional-toggle')
      if (conditionalToggle && conditionalToggle.checked) {
        this.updateConditionalFieldDropdown(field)
      }
    })
  }

  // Submit form
  submitForm(event) {
    event.preventDefault()

    console.log("Form submission started")

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
      .then(response => {
        console.log("Response received:", response)
        return response.json()
      })
      .then(data => {
        console.log("Data parsed:", data)

        if (data.success) {
          alert(data.message)
          this.closeModal(new Event('click')) // Pass a dummy event

          console.log("About to redirect to:", data.redirect)

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

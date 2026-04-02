// form_builder_controller.js - Updates needed for improved modal scrolling

import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"
import ToastController from "controllers/toast_controller"

export default class extends Controller {
  static targets = [
    "form",
    "formName",
    "pageCount",
    "pageHeadersContainer",
    "pageHeadersList",
    "fieldsContainer",
    "fieldItem",
    "submitButton",
    "submissionType",
    "approvalRoutingContainer",
    "routingStepsContainer",
    "routingStepItem",
    "statusConfigSection",
    "statusAutoMessage",
    "statusManualConfig",
    "statusesContainer",
    "statusItem",
    "predefinedStatusesList",
    "wizardPage",
    "wizardDot",
    "wizardPrevBtn",
    "wizardNextBtn",
    "wizardPageLabel",
    "wizardSubmitBtn"
  ]

  static values = {
    aclGroups: Array,
    employees: Array,
    predefinedStatuses: Array,
    validCategories: Array,
    editMode: { type: Boolean, default: false }
  }

  connect() {
    console.log("Form Builder controller connected")
    // Add one field by default only if we're in the create modal (not edit page)
    if (!this.editModeValue) {
      const template = document.getElementById('field-template')
      if (template) {
        this.addField()
      }
    }

    // Initialize sortable on fields container
    this.initializeSortable()

    // Initialize wizard navigation
    this.initializeWizard()
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

      this.resetWizard()
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
      if (this.hasOrgScopeContainerTarget) {
        this.orgScopeContainerTarget.style.display = 'none'
        this.clearOrgScope()
      }
      this.approvalRoutingContainerTarget.style.display = 'none'
      this.routingStepsContainerTarget.innerHTML = ''
      if (this.hasStatusesContainerTarget) {
        this.statusesContainerTarget.innerHTML = ''
      }
      // Close status picker if open
      this.closeStatusPicker()

      this.resetWizard()
    }
  }

  // Close modal when clicking outside the modal content
  clickOutside(event) {
    if (event.target.id === 'create-form-modal') {
      this.closeModal(event)
    }
  }

  // Toggle approval routing options based on submission type
  toggleApprovalRouting(event) {
    const submissionType = event.target.value
    const container = this.approvalRoutingContainerTarget
    const isApproval = submissionType === 'approval'

    if (isApproval) {
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

    // Toggle status config: approval shows auto message, database shows manual config
    if (this.hasStatusAutoMessageTarget) {
      this.statusAutoMessageTarget.style.display = isApproval ? 'block' : 'none'
    }
    if (this.hasStatusManualConfigTarget) {
      this.statusManualConfigTarget.style.display = isApproval ? 'none' : 'block'
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

    // Also update the display name placeholder
    this.updateStepDisplayName(event)
  }

  // Update the display name input placeholder based on routing type
  updateStepDisplayName(event) {
    const routingType = event.target.value
    const stepItem = event.target.closest('.routing-step-item')
    const displayNameInput = stepItem.querySelector('.step-display-name-input')

    if (!displayNameInput) return

    const labels = {
      'supervisor': 'Sent to Supervisor',
      'department_head': 'Sent to Department Head',
      'employee': 'Sent to Employee'
    }
    displayNameInput.placeholder = labels[routingType] || 'e.g. Sent to HR (auto-generated if blank)'
  }

  // ============================================
  // STATUS CONFIGURATION METHODS
  // ============================================

  // Show the status picker modal
  showStatusPicker(event) {
    if (event) event.preventDefault()

    const modal = document.getElementById('status-picker-modal')
    const listContainer = this.predefinedStatusesListTarget

    if (!modal || !listContainer) return

    // Get currently added status keys
    const addedKeys = this.getAddedStatusKeys()

    // Populate predefined statuses list
    listContainer.innerHTML = ''

    this.predefinedStatusesValue.forEach(status => {
      const isAdded = addedKeys.includes(status.key)
      const item = document.createElement('div')
      item.style.cssText = 'display: flex; justify-content: space-between; align-items: center; padding: 10px; border-bottom: 1px solid #eee;'
      item.innerHTML = `
        <div>
          <strong>${status.name}</strong>
          <span class="badge ${this.getCategoryBadgeClass(status.category)}" style="margin-left: 8px;">${this.getCategoryLabel(status.category)}</span>
          ${status.is_initial ? '<small style="color: #6c757d; margin-left: 8px;">(Initial)</small>' : ''}
          ${status.is_end ? '<small style="color: #6c757d; margin-left: 8px;">(End)</small>' : ''}
        </div>
        <button type="button"
                class="btn btn-sm ${isAdded ? 'btn-secondary' : 'btn-primary'}"
                data-status-key="${status.key}"
                ${isAdded ? 'disabled' : ''}
                data-action="click->form-builder#addPredefinedStatus">
          ${isAdded ? 'Added' : 'Add'}
        </button>
      `
      listContainer.appendChild(item)
    })

    modal.style.display = 'flex'
  }

  // Close the status picker modal
  closeStatusPicker(event) {
    if (event) event.preventDefault()
    const modal = document.getElementById('status-picker-modal')
    if (modal) {
      modal.style.display = 'none'
    }
  }

  // Get array of currently added status keys
  getAddedStatusKeys() {
    const keys = []
    this.statusItemTargets.forEach(item => {
      const keyInput = item.querySelector('.status-key-input')
      if (keyInput && keyInput.value) {
        keys.push(keyInput.value)
      }
    })
    return keys
  }

  // Add a predefined status
  addPredefinedStatus(event) {
    if (event) event.preventDefault()

    const statusKey = event.target.dataset.statusKey
    const statusData = this.predefinedStatusesValue.find(s => s.key === statusKey)

    if (!statusData) return

    const template = document.getElementById('status-item-template')
    if (!template) return

    const clone = template.content.cloneNode(true)
    const item = clone.querySelector('.status-item')

    // Set values
    item.querySelector('.status-name-text').textContent = statusData.name
    item.querySelector('.status-name-input').value = statusData.name
    item.querySelector('.status-key-input').value = statusData.key
    item.querySelector('.status-category-input').value = statusData.category

    // Set category badge
    const badge = item.querySelector('.status-category-badge')
    badge.textContent = this.getCategoryLabel(statusData.category)
    badge.className = `badge ${this.getCategoryBadgeClass(statusData.category)}`

    // Set flags
    if (statusData.is_initial) {
      item.querySelector('.status-initial-input').checked = true
    }
    if (statusData.is_end) {
      item.querySelector('.status-end-input').checked = true
    }

    this.statusesContainerTarget.appendChild(clone)
    this.updateStatusPositions()


    // Update the picker button state
    event.target.textContent = 'Added'
    event.target.disabled = true
    event.target.classList.remove('btn-primary')
    event.target.classList.add('btn-secondary')
  }

  // Add a custom status
  addCustomStatus(event) {
    if (event) event.preventDefault()

    const template = document.getElementById('custom-status-template')
    if (!template) return

    const clone = template.content.cloneNode(true)
    this.statusesContainerTarget.appendChild(clone)
    this.updateStatusPositions()


    // Focus the name input
    const addedItem = this.statusesContainerTarget.lastElementChild
    const nameInput = addedItem.querySelector('.status-name-input')
    if (nameInput) nameInput.focus()
  }

  // Remove a status
  removeStatus(event) {
    if (event) event.preventDefault()

    const statusItem = event.target.closest('.status-item')
    if (statusItem) {
      statusItem.remove()
      this.updateStatusPositions()
  
    }
  }

  // Update status position indicators
  updateStatusPositions() {
    this.statusItemTargets.forEach((item, index) => {
      const positionLabel = item.querySelector('.status-position')
      const positionInput = item.querySelector('.status-position-input')
      if (positionLabel) positionLabel.textContent = `#${index + 1}`
      if (positionInput) positionInput.value = index
    })
  }

  // Generate status key from name (for custom statuses)
  generateStatusKey(event) {
    const nameInput = event.target
    const statusItem = nameInput.closest('.status-item')
    const keyInput = statusItem.querySelector('.status-key-input')

    if (keyInput) {
      // Convert to snake_case key
      keyInput.value = nameInput.value
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, '')
        .replace(/\s+/g, '_')
        .replace(/^_+|_+$/g, '')
    }

    // Refresh step status dropdowns when status name changes

  }

  // Handle end checkbox toggle - refresh step status dropdowns
  handleEndStatusToggle(event) {

  }

  // Get category badge CSS class
  getCategoryBadgeClass(category) {
    const classes = {
      'pending': 'is-pending',
      'in_review': 'is-in-review',
      'approved': 'is-approved',
      'denied': 'is-denied',
      'cancelled': 'is-cancelled',
      'scheduled': 'is-scheduled'
    }
    return classes[category] || 'is-pending'
  }

  // Get category label
  getCategoryLabel(category) {
    const labels = {
      'pending': 'Pending',
      'in_review': 'In Review',
      'approved': 'Approved',
      'denied': 'Denied',
      'cancelled': 'Cancelled',
      'scheduled': 'Scheduled'
    }
    return labels[category] || category
  }

  // ============================================
  // POWER BI METHODS
  // ============================================

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

    // Preserve existing page header values before rebuilding
    const existingValues = []
    headersList.querySelectorAll('input').forEach(input => {
      existingValues.push(input.value)
    })

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
                data-action="input->form-builder#refreshPageSelects"
                required>
        `
        // Restore previously entered value if it exists
        const savedValue = existingValues[i - 3]
        if (savedValue) {
          headerItem.querySelector('input').value = savedValue
        }
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

  // Refresh page selects when page header names change
  refreshPageSelects() {
    const pageCount = parseInt(this.pageCountTarget.value)
    this.updatePageSelects(pageCount)
  }

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
    } else if (fieldType === 'dropdown' || fieldType === 'choices_dropdown') {
      dropdownOptions.style.display = 'block'
    }

    // Show/hide conditional answer options (only for dropdown types)
    const conditionalAnswerOptions = fieldItem.querySelector('.conditional-answer-options')
    if (conditionalAnswerOptions) {
      if (fieldType === 'dropdown' || fieldType === 'choices_dropdown') {
        conditionalAnswerOptions.style.display = 'block'
      } else {
        conditionalAnswerOptions.style.display = 'none'
        // Clear conditional answer config when switching away from dropdown
        const conditionalAnswerToggle = fieldItem.querySelector('.conditional-answer-toggle')
        if (conditionalAnswerToggle) conditionalAnswerToggle.checked = false
        const conditionalAnswerConfig = fieldItem.querySelector('.conditional-answer-config')
        if (conditionalAnswerConfig) conditionalAnswerConfig.style.display = 'none'
      }
    }

    // Refresh conditional dropdowns in other fields (they may now see this as a dropdown option)
    this.refreshConditionalDropdowns()
  }

  // Toggle between manual values and database table for dropdown source
  handleDropdownSourceChange(event) {
    const fieldItem = event.target.closest('.field-item')
    const source = event.target.value
    const manualSection = fieldItem.querySelector('.dropdown-manual-values')
    const dataSourceSection = fieldItem.querySelector('.dropdown-data-source')

    // Uncheck other radios in this field item (since they share no name attribute)
    fieldItem.querySelectorAll('.dropdown-source-radio').forEach(radio => {
      radio.checked = (radio === event.target)
    })

    if (source === 'database') {
      manualSection.style.display = 'none'
      dataSourceSection.style.display = 'block'
    } else {
      manualSection.style.display = 'block'
      dataSourceSection.style.display = 'none'
      // Clear data source selects when switching back to manual
      const tableSelect = fieldItem.querySelector('.data-source-table-select')
      const columnSelect = fieldItem.querySelector('.data-source-column-select')
      if (tableSelect) tableSelect.value = ''
      if (columnSelect) {
        columnSelect.innerHTML = '<option value="">Select column...</option>'
      }
    }
  }

  // Populate column dropdown when a data source table is selected
  handleDataSourceTableChange(event) {
    const fieldItem = event.target.closest('.field-item')
    const columnSelect = fieldItem.querySelector('.data-source-column-select')
    const agencyOption = fieldItem.querySelector('.data-source-agency-option')
    const selectedOption = event.target.selectedOptions[0]

    columnSelect.innerHTML = '<option value="">Select column...</option>'

    // Show/hide the Agency filter dropdown (only for employees)
    if (agencyOption) {
      const isEmployees = selectedOption?.value === 'employees'
      agencyOption.style.display = isEmployees ? 'block' : 'none'
      if (isEmployees) {
        this.populateAgencySelect(agencyOption.querySelector('.data-source-agency-select'))
      } else {
        const agencySelect = agencyOption.querySelector('.data-source-agency-select')
        if (agencySelect) agencySelect.value = ''
      }
    }

    if (!selectedOption || !selectedOption.value) return

    try {
      const columns = JSON.parse(selectedOption.dataset.columns)
      for (const [key, label] of Object.entries(columns)) {
        const option = document.createElement('option')
        option.value = key
        option.textContent = label
        columnSelect.appendChild(option)
      }
    } catch (e) {
      console.error('Error parsing column data:', e)
    }
  }

  async populateAgencySelect(select) {
    if (!select || select.options.length > 1) return
    try {
      const response = await fetch('/lookups/agencies.json')
      const agencies = await response.json()
      agencies.forEach(([name, id]) => {
        const option = document.createElement('option')
        option.value = id
        option.textContent = name
        select.appendChild(option)
      })
    } catch (e) {
      console.error('Error loading agencies:', e)
    }
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

    // Preserve current selection to restore after rebuild
    const currentValue = conditionalSelect.value

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

      // Only include dropdown fields (regular and choices)
      if (typeSelect && (typeSelect.value === 'dropdown' || typeSelect.value === 'choices_dropdown') && labelInput) {
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

    // Restore selection if it still exists in the new options
    if (currentValue) {
      const matchingOption = conditionalSelect.querySelector(`option[value="${currentValue}"]`)
      if (matchingOption) {
        conditionalSelect.value = currentValue
      }
    }
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

  // Validate conditional fields before form submission
  validateConditionalFields() {
    let isValid = true
    const allFields = this.fieldsContainerTarget.querySelectorAll('.field-item')

    allFields.forEach(field => {
      const conditionalToggle = field.querySelector('.conditional-toggle')
      if (conditionalToggle && conditionalToggle.checked) {
        const conditionalSelect = field.querySelector('.conditional-field-select')
        const checkedValues = field.querySelectorAll('.conditional-values-container input[type="checkbox"]:checked')

        if (!conditionalSelect || !conditionalSelect.value) {
          if (checkedValues.length > 0) {
            // Values are checked but no dropdown selected - clear the checkboxes
            checkedValues.forEach(cb => cb.checked = false)
          }
          // Also uncheck the conditional toggle since no dropdown is selected
          conditionalToggle.checked = false
          const conditionalConfig = field.querySelector('.conditional-config')
          if (conditionalConfig) conditionalConfig.style.display = 'none'
        } else if (checkedValues.length === 0) {
          // Dropdown selected but no values checked - show warning
          const labelInput = field.querySelector('input[name="fields[][label]"]')
          const fieldName = labelInput ? labelInput.value : 'A field'
          alert(`"${fieldName}" has conditional display enabled but no trigger values selected. Please select at least one value or uncheck "Show conditionally".`)
          isValid = false
        }
      }
    })

    return isValid
  }

  // Refresh all conditional dropdowns when field types change
  refreshConditionalDropdowns() {
    const allFields = this.fieldsContainerTarget.querySelectorAll('.field-item')
    allFields.forEach(field => {
      const conditionalToggle = field.querySelector('.conditional-toggle')
      if (conditionalToggle && conditionalToggle.checked) {
        this.updateConditionalFieldDropdown(field)
      }
      const answerToggle = field.querySelector('.conditional-answer-toggle')
      if (answerToggle && answerToggle.checked) {
        this.updateConditionalAnswerFieldDropdown(field)
      }
    })
  }

  // Called when dropdown values are changed - update any conditional fields that depend on this dropdown
  handleDropdownValuesChange(event) {
    // Refresh conditional dropdowns in other fields to pick up the new values
    this.refreshConditionalDropdowns()

    // Also refresh any conditional value checkboxes that reference this field
    const changedField = event.target.closest('.field-item')
    const allFields = this.fieldsContainerTarget.querySelectorAll('.field-item')
    const changedFieldIndex = Array.from(allFields).indexOf(changedField)

    allFields.forEach(field => {
      const conditionalSelect = field.querySelector('.conditional-field-select')
      if (conditionalSelect && conditionalSelect.value === `field_${changedFieldIndex}`) {
        // This field depends on the changed dropdown - refresh its value checkboxes
        this.updateConditionalValues({ target: conditionalSelect })
      }

      // Also refresh conditional answer mappings that reference this field
      const answerSelect = field.querySelector('.conditional-answer-field-select')
      if (answerSelect && answerSelect.value === `field_${changedFieldIndex}`) {
        this.updateConditionalAnswerMappings({ target: answerSelect })
      }
    })
  }

  // Toggle conditional answer options visibility
  toggleConditionalAnswerOptions(event) {
    const fieldItem = event.target.closest('.field-item')
    const config = fieldItem.querySelector('.conditional-answer-config')
    const isChecked = event.target.checked

    if (config) {
      config.style.display = isChecked ? 'block' : 'none'

      if (isChecked) {
        this.updateConditionalAnswerFieldDropdown(fieldItem)
      } else {
        const answerSelect = fieldItem.querySelector('.conditional-answer-field-select')
        if (answerSelect) answerSelect.value = ''
        const mappingsContainer = fieldItem.querySelector('.conditional-answer-mappings-container')
        if (mappingsContainer) {
          mappingsContainer.innerHTML = '<span style="font-size: 0.8em; color: #6c757d; font-style: italic;">Select a trigger dropdown first</span>'
        }
      }
    }
  }

  // Update the conditional answer field dropdown with available dropdown fields
  updateConditionalAnswerFieldDropdown(fieldItem) {
    const answerSelect = fieldItem.querySelector('.conditional-answer-field-select')
    if (!answerSelect) return

    const currentValue = answerSelect.value
    const allFields = this.fieldsContainerTarget.querySelectorAll('.field-item')
    const currentFieldIndex = Array.from(allFields).indexOf(fieldItem)

    answerSelect.innerHTML = '<option value="">Select dropdown...</option>'

    allFields.forEach((field, index) => {
      if (index === currentFieldIndex) return

      const typeSelect = field.querySelector('select[name="fields[][field_type]"]')
      const labelInput = field.querySelector('input[name="fields[][label]"]')
      const dropdownValuesInput = field.querySelector('input[name="fields[][dropdown_values]"]')

      if (typeSelect && (typeSelect.value === 'dropdown' || typeSelect.value === 'choices_dropdown') && labelInput) {
        const option = document.createElement('option')
        option.value = `field_${index}`
        option.textContent = labelInput.value || `Field ${index + 1}`
        option.dataset.fieldIndex = index

        if (dropdownValuesInput && dropdownValuesInput.value) {
          option.dataset.values = JSON.stringify(
            dropdownValuesInput.value.split(',').map(v => v.trim()).filter(v => v)
          )
        }

        answerSelect.appendChild(option)
      }
    })

    if (currentValue) {
      const matchingOption = answerSelect.querySelector(`option[value="${currentValue}"]`)
      if (matchingOption) answerSelect.value = currentValue
    }
  }

  // Update conditional answer mapping rows when a trigger dropdown is selected
  updateConditionalAnswerMappings(event) {
    const fieldItem = event.target.closest('.field-item')
    const mappingsContainer = fieldItem.querySelector('.conditional-answer-mappings-container')
    const selectedOption = event.target.selectedOptions[0]

    if (!mappingsContainer) return
    mappingsContainer.innerHTML = ''

    if (!selectedOption || !selectedOption.value) {
      mappingsContainer.innerHTML = '<span style="font-size: 0.8em; color: #6c757d; font-style: italic;">Select a trigger dropdown first</span>'
      return
    }

    // Get trigger dropdown values
    let triggerValues = []
    if (selectedOption.dataset.fieldIndex !== undefined) {
      const allFields = this.fieldsContainerTarget.querySelectorAll('.field-item')
      const targetField = allFields[parseInt(selectedOption.dataset.fieldIndex)]
      if (targetField) {
        const dropdownValuesInput = targetField.querySelector('input[name="fields[][dropdown_values]"]')
        if (dropdownValuesInput && dropdownValuesInput.value) {
          triggerValues = dropdownValuesInput.value.split(',').map(v => v.trim()).filter(v => v)
        }
      }
    }
    if (triggerValues.length === 0 && selectedOption.dataset.values) {
      try { triggerValues = JSON.parse(selectedOption.dataset.values) } catch (e) { /* ignore */ }
    }

    if (triggerValues.length === 0) {
      mappingsContainer.innerHTML = '<span style="font-size: 0.8em; color: #6c757d; font-style: italic;">No values defined for this dropdown</span>'
      return
    }

    // Get this field's own dropdown values (for the answer select)
    let ownValues = []
    const ownDropdownValuesInput = fieldItem.querySelector('input[name="fields[][dropdown_values]"]')
    if (ownDropdownValuesInput && ownDropdownValuesInput.value) {
      ownValues = ownDropdownValuesInput.value.split(',').map(v => v.trim()).filter(v => v)
    }

    if (ownValues.length === 0) {
      mappingsContainer.innerHTML = '<span style="font-size: 0.8em; color: #6c757d; font-style: italic;">Add dropdown values to this field first</span>'
      return
    }

    // Create mapping rows: trigger value → answer select
    triggerValues.forEach(triggerValue => {
      const row = document.createElement('div')
      row.style.cssText = 'display: flex; align-items: center; gap: 8px; font-size: 0.8em;'

      const label = document.createElement('span')
      label.style.cssText = 'min-width: 120px; background: #fff; padding: 4px 8px; border-radius: 4px; border: 1px solid #ddd;'
      label.textContent = triggerValue

      const arrow = document.createElement('span')
      arrow.style.color = '#495057'
      arrow.innerHTML = '&rarr;'

      const select = document.createElement('select')
      select.name = `fields[][conditional_answer_mappings][${triggerValue}]`
      select.className = 'form-control form-control-sm'
      select.style.cssText = 'width: auto; min-width: 120px;'

      const emptyOption = document.createElement('option')
      emptyOption.value = ''
      emptyOption.textContent = 'No auto-answer'
      select.appendChild(emptyOption)

      ownValues.forEach(answerValue => {
        const opt = document.createElement('option')
        opt.value = answerValue
        opt.textContent = answerValue
        select.appendChild(opt)
      })

      row.appendChild(label)
      row.appendChild(arrow)
      row.appendChild(select)
      mappingsContainer.appendChild(row)
    })
  }

  // Validate form before regular submission (legacy, kept for compatibility)
  validateBeforeSubmit(event) {
    console.log("Validating form before submit")

    if (!this.validateConditionalFields()) {
      event.preventDefault()
      return false
    }

    return true
  }

  // Submit edit form - validates conditional fields, shows loading overlay + toast
  submitEditForm(event) {
    event.preventDefault()

    console.log("Validating edit form before submit")

    if (!this.validateConditionalFields()) {
      return
    }

    // Disable submit button to prevent double submission
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = 'Updating...'

    // Show loading overlay
    const formWrapper = this.element.querySelector('.form-wrapper') || this.element
    const overlay = this.showLoadingOverlay(formWrapper, 'Updating form template...')

    const form = this.element.querySelector('form') || this.element.closest('form')
    const formData = new FormData(form)

    fetch(form.action, {
      method: form.method || 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'application/json'
      }
    })
      .then(response => response.json())
      .then(data => {
        this.removeLoadingOverlay(overlay)

        if (data.success) {
          ToastController.show('success', data.message)

          if (data.redirect) {
            setTimeout(() => { window.location.href = data.redirect }, 1000)
          } else {
            setTimeout(() => { window.location.reload() }, 1000)
          }
        } else {
          ToastController.show('error', 'Error updating form: ' + data.errors.join(', '))
          this.submitButtonTarget.disabled = false
          this.submitButtonTarget.textContent = 'Update Form Template'
        }
      })
      .catch(error => {
        this.removeLoadingOverlay(overlay)
        ToastController.show('error', 'An unexpected error occurred.')
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.textContent = 'Update Form Template'
        console.error('Edit form submission error:', error)
      })
  }

  // ============================================
  // WIZARD NAVIGATION METHODS
  // ============================================

  initializeWizard() {
    if (!this.hasWizardPageTarget) return
    this.currentWizardPage = 0
    this.showWizardPage()
  }

  showWizardPage() {
    if (!this.hasWizardPageTarget) return

    const page = this.currentWizardPage

    // Toggle page visibility
    this.wizardPageTargets.forEach((el, i) => {
      el.style.display = i === page ? 'block' : 'none'
    })

    // Update dots
    this.wizardDotTargets.forEach((dot, i) => {
      dot.classList.toggle('active', i === page)
    })

    // Show/hide prev button
    if (this.hasWizardPrevBtnTarget) {
      this.wizardPrevBtnTarget.style.display = page === 0 ? 'none' : 'inline-block'
    }

    // Show/hide next button
    const lastPage = this.wizardPageTargets.length - 1
    if (this.hasWizardNextBtnTarget) {
      this.wizardNextBtnTarget.style.display = page === lastPage ? 'none' : 'inline-block'
    }

    // Show/hide submit button (only on last page)
    if (this.hasWizardSubmitBtnTarget) {
      this.wizardSubmitBtnTarget.style.display = page === lastPage ? 'inline-block' : 'none'
    }

    // Update page label
    if (this.hasWizardPageLabelTarget) {
      const currentPageEl = this.wizardPageTargets[page]
      const title = currentPageEl?.dataset.wizardTitle || `Step ${page + 1}`
      this.wizardPageLabelTarget.textContent = `Step ${page + 1} of ${this.wizardPageTargets.length} — ${title}`
    }

    // Scroll modal body to top (works for both modal and edit page)
    const modalBody = this.element.querySelector('.modal-body')
    if (modalBody) modalBody.scrollTop = 0

    // For full-page edit wizard, scroll the wrapper to top
    const editWrapper = this.element.closest('.edit-wizard-wrapper')
    if (editWrapper) editWrapper.scrollTop = 0
  }

  wizardNext(event) {
    if (event) event.preventDefault()
    if (!this.hasWizardPageTarget) return

    if (!this.validateWizardPage(this.currentWizardPage)) return

    if (this.currentWizardPage < this.wizardPageTargets.length - 1) {
      this.currentWizardPage++
      this.showWizardPage()
    }
  }

  wizardPrev(event) {
    if (event) event.preventDefault()
    if (!this.hasWizardPageTarget) return

    if (this.currentWizardPage > 0) {
      this.currentWizardPage--
      this.showWizardPage()
    }
  }

  validateWizardPage(pageIndex) {
    const page = this.wizardPageTargets[pageIndex]
    if (!page) return true

    // Check all visible required inputs on this page
    const inputs = page.querySelectorAll('input[required], select[required], textarea[required]')
    for (const input of inputs) {
      // Skip hidden inputs (e.g. inside display:none containers)
      if (input.offsetParent === null && input.type !== 'hidden') continue
      if (!input.reportValidity()) return false
    }
    return true
  }

  resetWizard() {
    if (!this.hasWizardPageTarget) return
    this.currentWizardPage = 0
    this.showWizardPage()
  }

  // Submit form
  showLoadingOverlay(container, message) {
    const overlay = document.createElement('div')
    overlay.className = 'loading-overlay'
    overlay.innerHTML = `
      <div class="loading-spinner"></div>
      <span class="loading-text">${message}</span>
    `
    container.style.position = 'relative'
    container.appendChild(overlay)
    return overlay
  }

  removeLoadingOverlay(overlay) {
    if (overlay) overlay.remove()
  }

  submitForm(event) {
    event.preventDefault()

    console.log("Form submission started")

    // Validate conditional fields
    if (!this.validateConditionalFields()) {
      return
    }

    // Disable submit button to prevent double submission
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = 'Creating...'

    // Show loading overlay on the modal content
    const modalContent = this.element.querySelector('.form-builder-modal-content')
    const overlay = this.showLoadingOverlay(modalContent, 'Creating form...')

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
          this.removeLoadingOverlay(overlay)
          ToastController.show('success', data.message)
          this.closeModal(new Event('click'))

          console.log("About to redirect to:", data.redirect)

          if (data.redirect) {
            setTimeout(() => { window.location.href = data.redirect }, 1000)
          } else {
            setTimeout(() => { window.location.reload() }, 1000)
          }
        } else {
          this.removeLoadingOverlay(overlay)
          ToastController.show('error', 'Error creating form: ' + data.errors.join(', '))
          this.submitButtonTarget.disabled = false
          this.submitButtonTarget.textContent = 'Create Form'
        }
      })
      .catch(error => {
        console.error('Error:', error)
        this.removeLoadingOverlay(overlay)
        ToastController.show('error', 'An error occurred while creating the form.')
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.textContent = 'Create Form'
      })
  }
}

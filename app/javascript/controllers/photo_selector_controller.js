import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="photo-selector"
export default class extends Controller {
  static targets = ["checkbox", "submitButton", "selectAllButton", "selectedCount"]
  static values = {
    albumId: Number
  }

  connect() {
    this.updateUI()
  }

  toggleSelection(event) {
    this.updateUI()
  }

  selectAll(event) {
    event.preventDefault()
    const allChecked = this.checkboxTargets.every(checkbox => checkbox.checked)
    
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = !allChecked
    })
    
    this.updateUI()
  }

  updateUI() {
    const selectedCount = this.selectedCheckboxes().length
    
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = selectedCount === 0
      
      // Update button text
      if (selectedCount === 0) {
        this.submitButtonTarget.textContent = "Add Selected Photos"
      } else {
        this.submitButtonTarget.textContent = `Add ${selectedCount} Photo${selectedCount > 1 ? 's' : ''} to Album`
      }
    }
    
    if (this.hasSelectAllButtonTarget) {
      const allChecked = this.checkboxTargets.every(checkbox => checkbox.checked)
      this.selectAllButtonTarget.textContent = allChecked ? "Deselect All" : "Select All"
    }

    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = `${selectedCount} selected`
    }
  }

  selectedCheckboxes() {
    return this.checkboxTargets.filter(checkbox => checkbox.checked)
  }

  submitSelection(event) {
    event.preventDefault()
    
    const selectedPhotoIds = this.selectedCheckboxes().map(checkbox => checkbox.value)
    
    if (selectedPhotoIds.length === 0) {
      return
    }

    // Create form and submit
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = `/albums/${this.albumIdValue}/add_photos`
    
    // Add CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]').content
    const csrfInput = document.createElement('input')
    csrfInput.type = 'hidden'
    csrfInput.name = 'authenticity_token'
    csrfInput.value = csrfToken
    form.appendChild(csrfInput)
    
    // Add photo IDs
    selectedPhotoIds.forEach(photoId => {
      const input = document.createElement('input')
      input.type = 'hidden'
      input.name = 'photo_ids[]'
      input.value = photoId
      form.appendChild(input)
    })
    
    document.body.appendChild(form)
    form.submit()
  }
}

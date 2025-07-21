import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview"]

  change() {
    const file = this.inputTarget.files[0]
    if (file) {
      if (!this.validateFile(file)) {
        this.inputTarget.value = ''
        return
      }
      this.showPreview(file)
    }
  }

  validateFile(file) {
    // Check file size (10MB limit)
    const maxSize = 10 * 1024 * 1024
    if (file.size > maxSize) {
      this.showError('File size must be less than 10MB')
      return false
    }

    // Check file type
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif']
    if (!allowedTypes.includes(file.type)) {
      this.showError('Please select a valid image file (JPEG, PNG, or GIF)')
      return false
    }

    return true
  }

  showPreview(file) {
    if (!this.hasPreviewTarget) return

    const reader = new FileReader()
    reader.onload = (e) => {
      this.previewTarget.innerHTML = `
        <img src="${e.target.result}" alt="Preview" style="max-width: 200px; max-height: 200px; border-radius: 4px; border: 1px solid #dee2e6;">
        <p class="small text-muted mt-1">${file.name} (${this.formatFileSize(file.size)})</p>
      `
    }
    reader.readAsDataURL(file)
  }

  showError(message) {
    // Find or create error container
    let errorContainer = this.element.querySelector('.file-error')
    if (!errorContainer) {
      errorContainer = document.createElement('div')
      errorContainer.className = 'file-error alert alert-danger mt-2'
      this.inputTarget.parentNode.appendChild(errorContainer)
    }
    errorContainer.textContent = message

    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (errorContainer.parentNode) {
        errorContainer.remove()
      }
    }, 5000)
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }
}
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  submit() {
    if (this.hasSubmitTarget) {
      this.showLoading(this.submitTarget)
    }
  }

  showLoading(button) {
    button.disabled = true
    button.dataset.originalText = button.textContent
    button.textContent = 'Loading...'
    button.classList.add('btn-loading')
  }

  hideLoading(button) {
    button.disabled = false
    button.textContent = button.dataset.originalText || button.textContent
    button.classList.remove('btn-loading')
  }
}
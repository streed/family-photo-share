import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { autoDismiss: Number }

  connect() {
    if (this.autoDismissValue > 0) {
      setTimeout(() => {
        this.dismiss()
      }, this.autoDismissValue)
    }
  }

  dismiss() {
    this.element.style.opacity = '0'
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.boundCloseOnClickOutside = this.closeOnClickOutside.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (this.menuTarget.classList.contains("show")) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.add("show")
    document.addEventListener("click", this.boundCloseOnClickOutside)
    document.addEventListener("keydown", this.closeOnEscape.bind(this))
  }

  close() {
    this.menuTarget.classList.remove("show")
    document.removeEventListener("click", this.boundCloseOnClickOutside)
    document.removeEventListener("keydown", this.closeOnEscape.bind(this))
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.boundCloseOnClickOutside)
    document.removeEventListener("keydown", this.closeOnEscape.bind(this))
  }
}
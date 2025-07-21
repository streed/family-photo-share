import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  connect() {
    this.boundCloseOnClickOutside = this.closeOnClickOutside.bind(this)
    this.boundCloseOnEscape = this.closeOnEscape.bind(this)
  }

  open() {
    this.element.classList.add("show")
    document.body.style.overflow = "hidden"
    document.addEventListener("click", this.boundCloseOnClickOutside)
    document.addEventListener("keydown", this.boundCloseOnEscape)
  }

  close() {
    this.element.classList.remove("show")
    document.body.style.overflow = ""
    document.removeEventListener("click", this.boundCloseOnClickOutside)
    document.removeEventListener("keydown", this.boundCloseOnEscape)
  }

  closeOnClickOutside(event) {
    if (event.target === this.element) {
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
    document.removeEventListener("keydown", this.boundCloseOnEscape)
    document.body.style.overflow = ""
  }
}
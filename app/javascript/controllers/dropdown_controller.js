import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    // Both handlers must be bound ONCE and reused. `fn.bind(this)` returns a new
    // function every call, so binding inline at removeEventListener time removed
    // nothing — every open leaked another keydown listener for the page's life.
    this.boundCloseOnClickOutside = this.closeOnClickOutside.bind(this)
    this.boundCloseOnEscape = this.closeOnEscape.bind(this)
    this.menuTarget.hidden = true
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (this.menuTarget.hidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.hidden = false
    this.element.querySelector("[data-dropdown-trigger]")?.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.boundCloseOnClickOutside)
    document.addEventListener("keydown", this.boundCloseOnEscape)
  }

  close() {
    this.menuTarget.hidden = true
    this.element.querySelector("[data-dropdown-trigger]")?.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.boundCloseOnClickOutside)
    document.removeEventListener("keydown", this.boundCloseOnEscape)
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
    document.removeEventListener("keydown", this.boundCloseOnEscape)
  }
}
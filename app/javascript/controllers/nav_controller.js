import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="nav"
//
// The small-screen navigation menu. The links live in the markup at all sizes;
// this only shows and hides the panel below the header bar, so navigation still
// works with JavaScript off (the panel is visible until Stimulus connects and
// closes it).
export default class extends Controller {
  static targets = ["panel", "toggle"]

  connect() {
    this.boundCloseOnEscape = this.closeOnEscape.bind(this)
    this.close()
  }

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.toggleTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("keydown", this.boundCloseOnEscape)
  }

  close() {
    this.panelTarget.hidden = true
    this.toggleTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("keydown", this.boundCloseOnEscape)
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
      this.toggleTarget.focus()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundCloseOnEscape)
  }
}

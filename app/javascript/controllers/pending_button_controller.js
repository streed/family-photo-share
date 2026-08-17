import { Controller } from "@hotwired/stimulus"

// Gives a form button an immediate "working on it" state.
//
// Adding a photo to an album previously did a silent round trip: no pressed
// state, no spinner, nothing until the page came back. Users clicked twice
// because there was no evidence the first click registered.
export default class extends Controller {
  static classes = ["pending"]

  connect() {
    this.reset = this.reset.bind(this)
    // Turbo caches the page on navigation; clear the state so a restored page
    // doesn't come back frozen mid-spinner.
    document.addEventListener("turbo:before-cache", this.reset)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.reset)
  }

  start() {
    this.element.classList.add(this.pendingClassName)
    this.element.setAttribute("aria-busy", "true")

    const button = this.element.querySelector("button, input[type=submit]")
    if (button) button.disabled = true
  }

  reset() {
    this.element.classList.remove(this.pendingClassName)
    this.element.removeAttribute("aria-busy")

    const button = this.element.querySelector("button, input[type=submit]")
    if (button) button.disabled = false
  }

  get pendingClassName() {
    return this.hasPendingClass ? this.pendingClass : "is-pending"
  }
}

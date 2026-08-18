import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
//
// Shows and hides a dialog. The dialog is a `dialog` target so the controller
// can live on the surrounding card and still own the overlay — previously it
// toggled the controller element itself, which meant the whole section had to
// be the modal.
export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this.boundCloseOnEscape = this.closeOnEscape.bind(this)
  }

  get dialog() {
    return this.hasDialogTarget ? this.dialogTarget : this.element
  }

  open() {
    this.previouslyFocused = document.activeElement
    this.dialog.classList.add("show")
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this.boundCloseOnEscape)

    const focusable = this.dialog.querySelector("input, button, [href], select, textarea")
    if (focusable) focusable.focus()
  }

  close() {
    this.dialog.classList.remove("show")
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.boundCloseOnEscape)

    if (this.previouslyFocused && this.previouslyFocused.focus) {
      this.previouslyFocused.focus()
      this.previouslyFocused = null
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundCloseOnEscape)
    document.body.style.overflow = ""
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggle"
//
// Shows or hides a panel from a checkbox, so a form can reveal the settings
// that only matter once an option is on. Replaces the inline <script> that used
// to do this on the album form.
export default class extends Controller {
  static targets = ["panel", "checkbox"]

  connect() {
    this.sync()
  }

  sync() {
    if (!this.hasPanelTarget || !this.hasCheckboxTarget) return
    this.panelTarget.hidden = !this.checkboxTarget.checked
  }
}

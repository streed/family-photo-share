import { Controller } from "@hotwired/stimulus"

// Polls a photo's image-processing status until it settles.
//
// The previous inline script polled every 2s forever with no cap: a photo whose
// job had died sat on "Processing optimized versions..." indefinitely, hitting
// the server every two seconds for as long as the tab stayed open. This backs
// off, gives up after a bounded number of attempts, and says so.
export default class extends Controller {
  static targets = ["message"]
  static values = {
    url: String,
    maxAttempts: { type: Number, default: 20 }
  }

  connect() {
    this.attempts = 0
    this.schedule(2000)
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  schedule(delay) {
    this.timer = setTimeout(() => this.check(), delay)
  }

  async check() {
    this.attempts += 1

    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok) throw new Error(`status ${response.status}`)

      const data = await response.json()

      if (data.settled) {
        window.location.reload()
        return
      }
    } catch (error) {
      console.error("Error checking processing status:", error)
    }

    if (this.attempts >= this.maxAttemptsValue) {
      this.giveUp()
      return
    }

    // Back off gradually: 2s, 3s, 4s ... capped at 15s.
    this.schedule(Math.min(2000 + this.attempts * 1000, 15000))
  }

  giveUp() {
    if (this.hasMessageTarget) {
      this.messageTarget.textContent =
        "Still processing. You can keep using the app — reload this page later to check."
    }
    const spinner = this.element.querySelector(".fa-spin")
    if (spinner) spinner.classList.remove("fa-spin")
  }
}

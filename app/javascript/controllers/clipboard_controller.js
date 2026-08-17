import { Controller } from "@hotwired/stimulus"

// Copy-to-clipboard with confirmation feedback.
//
// Replaces per-view inline scripts that bound their listeners inside
// DOMContentLoaded. That event fires once per full page load, and Turbo Drive
// swaps the body without firing it again — so every copy button in the app
// stopped working after the first Turbo navigation. Stimulus reconnects on
// every render, which is the whole point of using it here.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = {
    text: String,
    successLabel: { type: String, default: "Copied!" },
    resetAfter: { type: Number, default: 2000 }
  }

  disconnect() {
    if (this.resetTimer) clearTimeout(this.resetTimer)
  }

  async copy(event) {
    event.preventDefault()

    const button = this.hasButtonTarget ? this.buttonTarget : event.currentTarget
    const text = this.textToCopy()
    if (!text) return

    try {
      await this.writeToClipboard(text)
      this.showSuccess(button)
    } catch (error) {
      console.error("Failed to copy:", error)
      this.showFailure(button)
    }
  }

  textToCopy() {
    if (this.hasTextValue && this.textValue.length > 0) return this.textValue
    if (!this.hasSourceTarget) return null

    const source = this.sourceTarget
    return source.value !== undefined ? source.value : source.textContent.trim()
  }

  // navigator.clipboard is unavailable on insecure origins, which includes
  // self-hosted setups reached over plain http on a LAN.
  async writeToClipboard(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text)
    }

    const scratch = document.createElement("textarea")
    scratch.value = text
    scratch.setAttribute("readonly", "")
    scratch.style.position = "fixed"
    scratch.style.opacity = "0"
    document.body.appendChild(scratch)
    scratch.select()

    const ok = document.execCommand("copy")
    document.body.removeChild(scratch)
    if (!ok) throw new Error("copy command was rejected")
  }

  showSuccess(button) {
    this.flash(button, `<i class="fas fa-check" aria-hidden="true"></i> ${this.successLabelValue}`, "copied")
  }

  showFailure(button) {
    this.flash(button, '<i class="fas fa-xmark" aria-hidden="true"></i> Press Ctrl+C', "copy-failed")
  }

  flash(button, html, className) {
    if (!button) return
    if (this.originalHtml === undefined) this.originalHtml = button.innerHTML

    button.innerHTML = html
    button.classList.add(className)

    if (this.resetTimer) clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      button.innerHTML = this.originalHtml
      button.classList.remove("copied", "copy-failed")
    }, this.resetAfterValue)
  }
}

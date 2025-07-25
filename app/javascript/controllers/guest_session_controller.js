import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["countdown", "warning"]
  static values = { 
    expiresAt: Number,
    warningThreshold: { type: Number, default: 120 }, // Show warning at 2 minutes
    activityCheckInterval: { type: Number, default: 30000 } // Check activity every 30 seconds
  }

  connect() {
    this.updateCountdown()
    this.countdownTimer = setInterval(() => this.updateCountdown(), 1000)
    this.activityTimer = setInterval(() => this.checkForActivity(), this.activityCheckIntervalValue)
    this.lastActivity = Date.now()
    this.setupActivityListeners()
  }

  disconnect() {
    if (this.countdownTimer) clearInterval(this.countdownTimer)
    if (this.activityTimer) clearInterval(this.activityTimer)
    this.removeActivityListeners()
  }

  setupActivityListeners() {
    this.activityEvents = ['scroll', 'click', 'mousemove', 'keypress', 'touchstart']
    this.handleActivity = this.handleActivity.bind(this)
    
    this.activityEvents.forEach(event => {
      document.addEventListener(event, this.handleActivity, { passive: true })
    })
  }

  removeActivityListeners() {
    if (this.activityEvents && this.handleActivity) {
      this.activityEvents.forEach(event => {
        document.removeEventListener(event, this.handleActivity)
      })
    }
  }

  handleActivity() {
    this.lastActivity = Date.now()
  }

  checkForActivity() {
    // If there was activity in the last interval, extend the session
    const timeSinceActivity = Date.now() - this.lastActivity
    if (timeSinceActivity < this.activityCheckIntervalValue) {
      this.extendSession()
    }
  }

  extendSession() {
    // Make a request to extend the session
    fetch(window.location.href, {
      method: 'HEAD',
      credentials: 'same-origin'
    }).then(response => {
      if (response.ok) {
        // Update the expiration time from the cookie
        this.updateExpirationFromCookie()
      }
    }).catch(error => {
      // Session extension failed silently
    })
  }

  updateExpirationFromCookie() {
    const cookieValue = this.getCookie('guest_session_expires_at')
    if (cookieValue) {
      const newExpiresAt = parseInt(cookieValue) * 1000 // Convert to milliseconds
      if (newExpiresAt > this.expiresAtValue) {
        this.expiresAtValue = newExpiresAt
      }
    }
  }

  getCookie(name) {
    const value = `; ${document.cookie}`
    const parts = value.split(`; ${name}=`)
    if (parts.length === 2) return parts.pop().split(';').shift()
    return null
  }

  updateCountdown() {
    const now = Date.now()
    const timeLeft = this.expiresAtValue - now
    
    if (timeLeft <= 0) {
      this.handleSessionExpired()
      return
    }

    // Show warning when time is running low (but don't show countdown)
    if (timeLeft <= this.warningThresholdValue * 1000) {
      this.showWarning()
    } else {
      this.hideWarning()
    }
  }

  showWarning() {
    if (this.hasWarningTarget) {
      this.warningTarget.classList.remove('d-none')
    }
  }

  hideWarning() {
    if (this.hasWarningTarget) {
      this.warningTarget.classList.add('d-none')
    }
  }

  handleSessionExpired() {
    if (this.countdownTimer) clearInterval(this.countdownTimer)
    if (this.activityTimer) clearInterval(this.activityTimer)
    
    // Redirect to password form or show expiration message
    window.location.reload()
  }

}
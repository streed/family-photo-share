import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="slideshow"
export default class extends Controller {
  static targets = ["modal", "image", "title", "description", "user", "counter", "takenAt"]
  static values = { trackUrl: String }

  connect() {
    this.currentIndex = 0
    this.photos = []
    this.boundKeydown = this.handleKeydown.bind(this)
    
    // Collect all photo data when controller connects
    this.collectPhotos()
  }

  collectPhotos() {
    const photoItems = this.element.querySelectorAll('[data-slideshow-index-value]')
    this.photos = Array.from(photoItems).map((item, idx) => {
      const img = item.querySelector('.photo-thumbnail')
      if (!img) return null
      
      return {
        index: idx,
        id: item.dataset.slideshowPhotoIdValue,
        src: img.dataset.large || img.src,
        title: img.dataset.title || img.alt || 'Untitled',
        description: img.dataset.description || '',
        user: img.dataset.user || 'Unknown',
        takenAt: img.dataset.takenAt || '',
        alt: img.alt || ''
      }
    }).filter(photo => photo !== null)
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const clickedItem = event.currentTarget
    const index = parseInt(clickedItem.dataset.slideshowIndexValue) || 0
    
    // Ensure photos are collected
    if (this.photos.length === 0) {
      this.collectPhotos()
    }
    
    if (this.photos.length === 0 || !this.hasModalTarget) {
      return
    }
    
    this.currentIndex = Math.max(0, Math.min(index, this.photos.length - 1))

    // Remember where focus came from so it can be restored on close.
    this.previouslyFocused = document.activeElement

    this.showPhoto(this.currentIndex)
    this.modalTarget.classList.add('show')
    this.modalTarget.removeAttribute('aria-hidden')
    document.body.style.overflow = 'hidden'

    // Add keyboard event listener
    document.addEventListener('keydown', this.boundKeydown)

    this.focusFirstControl()

    // Extend session when opening slideshow
    this.extendGuestSession()
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('show')
      this.modalTarget.setAttribute('aria-hidden', 'true')
    }
    document.body.style.overflow = ''

    // Remove keyboard event listener
    document.removeEventListener('keydown', this.boundKeydown)

    // Return focus to whatever opened the slideshow, so keyboard users are not
    // dumped back at the top of the document.
    if (this.previouslyFocused && this.previouslyFocused.focus) {
      this.previouslyFocused.focus()
      this.previouslyFocused = null
    }
  }

  next() {
    if (this.photos.length === 0) return
    this.currentIndex = (this.currentIndex + 1) % this.photos.length
    this.showPhoto(this.currentIndex)
    this.extendGuestSession()
  }

  previous() {
    if (this.photos.length === 0) return
    this.currentIndex = this.currentIndex === 0 ? this.photos.length - 1 : this.currentIndex - 1
    this.showPhoto(this.currentIndex)
    this.extendGuestSession()
  }

  showPhoto(index) {
    const photo = this.photos[index]
    if (!photo) return

    // Update image if target exists
    if (this.hasImageTarget) {
      this.imageTarget.src = photo.src
      this.imageTarget.alt = photo.alt
    }
    
    // Update info if targets exist
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = photo.title
    }
    
    if (this.hasDescriptionTarget) {
      this.descriptionTarget.textContent = photo.description
      // Hide description if empty
      this.descriptionTarget.style.display = photo.description ? 'block' : 'none'
    }
    
    if (this.hasUserTarget) {
      this.userTarget.textContent = photo.user
    }
    
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = index + 1
    }
    
    if (this.hasTakenAtTarget) {
      if (photo.takenAt) {
        this.takenAtTarget.textContent = ` • ${photo.takenAt}`
        this.takenAtTarget.style.display = 'inline'
      } else {
        this.takenAtTarget.style.display = 'none'
      }
    }
    
    // Track photo view if we have a tracking URL
    if (this.hasTrackUrlValue && photo.id) {
      this.trackPhotoView(photo.id)
    }
  }
  
  trackPhotoView(photoId) {
    if (!this.trackUrlValue) return

    const headers = { 'Content-Type': 'application/json' }

    // Send the CSRF token so the endpoint doesn't have to skip verification.
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    if (token) headers['X-CSRF-Token'] = token

    fetch(this.trackUrlValue, {
      method: 'POST',
      headers: headers,
      body: JSON.stringify({ photo_id: photoId }),
      credentials: 'same-origin'
    }).catch(() => {
      // Tracking is best-effort; the slideshow works without it.
    })
  }

  handleKeydown(event) {
    switch(event.key) {
      case 'Escape':
        this.close()
        break
      case 'ArrowRight':
        event.preventDefault()
        this.next()
        break
      case 'ArrowLeft':
        event.preventDefault()
        this.previous()
        break
      case 'Tab':
        this.trapFocus(event)
        break
    }
  }

  // Keep Tab inside the dialog. Without this, tabbing walked out of an open
  // slideshow into the page behind it, which is still visually covered.
  trapFocus(event) {
    const focusable = this.focusableElements()
    if (focusable.length === 0) return

    const first = focusable[0]
    const last = focusable[focusable.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  focusableElements() {
    if (!this.hasModalTarget) return []
    return Array.from(
      this.modalTarget.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')
    ).filter((el) => el.offsetParent !== null)
  }

  focusFirstControl() {
    const focusable = this.focusableElements()
    if (focusable.length > 0) focusable[0].focus()
  }

  // Only meaningful for guest sessions, and only worth doing occasionally.
  // This used to fire a HEAD request on every open and every arrow keypress,
  // for signed-in users too — who have no guest session to extend at all.
  extendGuestSession() {
    if (!this.hasTrackUrlValue) return

    const now = Date.now()
    if (this.lastSessionPing && now - this.lastSessionPing < 60000) return
    this.lastSessionPing = now

    fetch(window.location.href, {
      method: 'HEAD',
      credentials: 'same-origin'
    }).catch(() => {
      // Session extension is best-effort; the slideshow keeps working without it.
    })
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener('keydown', this.boundKeydown)
    document.body.style.overflow = ''
  }
}
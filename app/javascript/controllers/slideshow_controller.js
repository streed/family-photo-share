import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="slideshow"
export default class extends Controller {
  static targets = ["modal", "image", "title", "description", "user", "counter"]

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
        src: img.dataset.large || img.src,
        title: img.dataset.title || img.alt || 'Untitled',
        description: img.dataset.description || '',
        user: img.dataset.user || 'Unknown',
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
    
    this.showPhoto(this.currentIndex)
    this.modalTarget.classList.add('show')
    document.body.style.overflow = 'hidden'
    
    // Add keyboard event listener
    document.addEventListener('keydown', this.boundKeydown)
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('show')
    }
    document.body.style.overflow = ''
    
    // Remove keyboard event listener
    document.removeEventListener('keydown', this.boundKeydown)
  }

  next() {
    if (this.photos.length === 0) return
    this.currentIndex = (this.currentIndex + 1) % this.photos.length
    this.showPhoto(this.currentIndex)
  }

  previous() {
    if (this.photos.length === 0) return
    this.currentIndex = this.currentIndex === 0 ? this.photos.length - 1 : this.currentIndex - 1
    this.showPhoto(this.currentIndex)
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
    }
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener('keydown', this.boundKeydown)
    document.body.style.overflow = ''
  }
}
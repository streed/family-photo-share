import { Controller } from "@hotwired/stimulus"

// Infinite scroll for a photo grid.
//
// Attach to a sentinel element placed after the grid. When it nears the
// viewport, the next page is fetched (as ordinary HTML), its tiles are appended
// to the grid, and the sentinel is updated to point at the following page — or
// removed when there are no more. The sentinel's link works without JS.
export default class extends Controller {
  static values = { url: String, container: String }

  connect() {
    this.loading = false
    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) this.load()
    }, { rootMargin: "600px 0px" })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  async load(event) {
    event?.preventDefault()
    if (this.loading || !this.urlValue) return
    this.loading = true
    this.element.setAttribute("aria-busy", "true")

    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "text/html" },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const doc = new DOMParser().parseFromString(await response.text(), "text/html")
      const grid = document.querySelector(this.containerValue)
      const incoming = doc.querySelector(this.containerValue)
      if (!grid || !incoming) throw new Error("grid not found")

      const known = new Set(Array.from(grid.children).map((el) => el.id).filter(Boolean))
      Array.from(incoming.children).forEach((tile) => {
        if (!tile.id || !known.has(tile.id)) grid.appendChild(document.importNode(tile, true))
      })

      // Tiles are numbered per render; renumber so the slideshow opens the right one.
      grid.querySelectorAll("[data-slideshow-index-value]").forEach((tile, i) => {
        tile.dataset.slideshowIndexValue = i
      })
      grid.dispatchEvent(new CustomEvent("infinite-scroll:loaded", { bubbles: true }))

      const next = doc.querySelector('[data-controller~="infinite-scroll"]')
      if (next?.dataset.infiniteScrollUrlValue) {
        this.urlValue = next.dataset.infiniteScrollUrlValue
        // Re-observe so a sentinel that is still on screen fires again.
        this.observer.unobserve(this.element)
        this.observer.observe(this.element)
      } else {
        this.element.remove()
      }
    } catch (error) {
      // Leave the "Load more" link in place so the user can retry.
      console.error("Infinite scroll failed:", error)
    } finally {
      this.loading = false
      this.element.removeAttribute("aria-busy")
    }
  }
}

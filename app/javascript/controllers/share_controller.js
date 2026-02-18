import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="share"
// Handles share button with clipboard copy, social sharing, Web Share API, and event tracking.
export default class extends Controller {
  static values = {
    url: String,
    title: String,
    episodeId: Number,
    shareEndpoint: String
  }

  connect() {
    this._debouncing = false
  }

  async copy() {
    const url = this._shareUrl("clipboard")
    await navigator.clipboard.writeText(url)
    this._trackShare("clipboard")
    this._showToast("Link copied!")
  }

  twitter() {
    const url = this._shareUrl("twitter")
    const text = `${this.titleValue} ${url}`
    window.open(`https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}`, "_blank")
    this._trackShare("twitter")
  }

  linkedin() {
    const url = this._shareUrl("linkedin")
    window.open(`https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(url)}`, "_blank")
    this._trackShare("linkedin")
  }

  async native() {
    const url = this._shareUrl("native")
    try {
      await navigator.share({ title: this.titleValue, url: url })
      this._trackShare("native")
    } catch (e) {
      // User cancelled or share failed — ignore
    }
  }

  toggle() {
    const menu = this.element.querySelector("[data-share-menu]")
    if (menu) {
      menu.classList.toggle("hidden")
    }
  }

  // Build the share URL with UTM params
  _shareUrl(target) {
    const url = new URL(this.urlValue)
    url.searchParams.set("utm_source", "share")
    url.searchParams.set("utm_medium", "social")
    url.searchParams.set("utm_content", `episode_${this.episodeIdValue}`)
    return url.toString()
  }

  // POST share event to the tracking endpoint (debounced)
  _trackShare(target) {
    if (this._debouncing) return
    this._debouncing = true
    setTimeout(() => { this._debouncing = false }, 1000)

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.shareEndpointValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": csrfToken
      },
      body: `share_target=${encodeURIComponent(target)}`
    }).catch(() => {})
  }

  _showToast(message) {
    const toast = document.createElement("div")
    toast.textContent = message
    toast.className = "fixed bottom-4 left-1/2 -translate-x-1/2 bg-gray-900 text-white px-4 py-2 rounded-lg text-sm shadow-lg z-50 transition-opacity duration-300"
    document.body.appendChild(toast)
    setTimeout(() => {
      toast.classList.add("opacity-0")
      setTimeout(() => toast.remove(), 300)
    }, 2000)
  }
}

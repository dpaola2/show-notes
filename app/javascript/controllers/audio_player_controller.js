import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="audio-player"
// This controller manages the audio element and provides seeking functionality
export default class extends Controller {
  static targets = ["audio", "currentTime", "duration", "progress"]

  connect() {
    // Register this audio element globally so audio-seek controllers can find it
    window.audioPlayer = this.element

    // Update duration when metadata loads
    this.element.addEventListener("loadedmetadata", () => {
      this.updateDuration()
    })

    // Update time display during playback
    this.element.addEventListener("timeupdate", () => {
      this.updateCurrentTime()
      this.updateProgress()
    })
  }

  disconnect() {
    if (window.audioPlayer === this.element) {
      window.audioPlayer = null
    }
  }

  // Seek to a specific time in seconds
  seek(time) {
    if (this.element && typeof time === "number") {
      this.element.currentTime = time
      this.element.play()
    }
  }

  updateCurrentTime() {
    if (this.hasCurrentTimeTarget) {
      this.currentTimeTarget.textContent = this.formatTime(this.element.currentTime)
    }
  }

  updateDuration() {
    if (this.hasDurationTarget) {
      this.durationTarget.textContent = this.formatTime(this.element.duration)
    }
  }

  updateProgress() {
    if (this.hasProgressTarget && this.element.duration) {
      const percent = (this.element.currentTime / this.element.duration) * 100
      this.progressTarget.style.width = `${percent}%`
    }
  }

  formatTime(seconds) {
    if (!seconds || isNaN(seconds)) return "0:00"

    const hours = Math.floor(seconds / 3600)
    const mins = Math.floor((seconds % 3600) / 60)
    const secs = Math.floor(seconds % 60)

    if (hours > 0) {
      return `${hours}:${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`
    }
    return `${mins}:${secs.toString().padStart(2, "0")}`
  }
}

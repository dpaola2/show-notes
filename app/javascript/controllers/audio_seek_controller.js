import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="audio-seek"
// Allows clicking on elements (like quotes) to seek the audio player to a timestamp
export default class extends Controller {
  static values = { time: Number }

  connect() {
    this.element.style.cursor = "pointer"
  }

  // Seek to the timestamp when clicking on this element
  seek(event) {
    event.preventDefault()

    const audioElement = window.audioPlayer || document.querySelector("audio")

    if (audioElement && this.hasTimeValue) {
      audioElement.currentTime = this.timeValue
      audioElement.play()

      // Scroll the audio player into view
      audioElement.scrollIntoView({ behavior: "smooth", block: "center" })
    }
  }
}

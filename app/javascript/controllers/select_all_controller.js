import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="select-all"
// Toggles all checkboxes in the target area
export default class extends Controller {
  static targets = ["checkbox"]

  toggle(event) {
    const checked = this.checkboxTargets.some(cb => !cb.checked)
    this.checkboxTargets.forEach(cb => cb.checked = checked)
    event.currentTarget.textContent = checked ? "Deselect all" : "Select all"
  }
}

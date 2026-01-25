import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
// Auto-dismisses flash messages after a delay
export default class extends Controller {
  static values = { dismissAfter: Number }

  connect() {
    if (this.hasDismissAfterValue && this.dismissAfterValue > 0) {
      setTimeout(() => {
        this.dismiss()
      }, this.dismissAfterValue)
    }
  }

  dismiss() {
    this.element.classList.add("opacity-0", "transition-opacity", "duration-300")
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}

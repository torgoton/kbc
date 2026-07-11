import { Controller } from "@hotwired/stimulus"

// Reveals the (server-gated) Claim victory button the moment the current
// player's clock flags. The button is authoritative server-side, so unhiding
// it early is harmless; this just surfaces an affordance the opponent's
// browser already has enough info to show without waiting for a broadcast.
export default class extends Controller {
  connect() {
    this.reveal = this.reveal.bind(this)
    window.addEventListener("clock:flagged", this.reveal)
  }

  disconnect() {
    window.removeEventListener("clock:flagged", this.reveal)
  }

  reveal() {
    this.element.hidden = false
  }
}

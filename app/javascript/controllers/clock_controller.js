import { Controller } from "@hotwired/stimulus"

// Display-only Fischer clock countdown. The server is authoritative: every
// broadcast_game_update re-sends the true remaining-ms value, which resets
// our local countdown (remainingMsValueChanged). We only tick locally
// between broadcasts so the display doesn't look frozen.
export default class extends Controller {
  static values = { remainingMs: Number, running: Boolean }

  connect() {
    this.render()
    this.runningValueChanged()
  }

  disconnect() {
    this.stop()
  }

  runningValueChanged() {
    this.runningValue ? this.start() : this.stop()
  }

  remainingMsValueChanged() {
    this.render()
  }

  start() {
    this.stop()
    this.timer = setInterval(() => {
      this.remainingMsValue -= 1000
    }, 1000)
  }

  stop() {
    clearInterval(this.timer)
  }

  render() {
    const ms = this.remainingMsValue
    const negative = ms < 0
    const totalSeconds = Math.floor(Math.abs(ms) / 1000)
    const minutes = Math.floor(totalSeconds / 60)
    const seconds = String(totalSeconds % 60).padStart(2, "0")
    this.element.textContent = `${negative ? "-" : ""}${minutes}:${seconds}`
    this.element.classList.toggle("clock-low", ms >= 0 && ms < 30_000)
    this.element.classList.toggle("clock-flagged", ms <= 0)
    // Only the current player's clock is running; when it flags, tell any
    // opponent's hidden claim-victory button to reveal itself (once).
    if (this.runningValue && ms <= 0 && !this.flagged) {
      this.flagged = true
      window.dispatchEvent(new CustomEvent("clock:flagged"))
    }
  }
}

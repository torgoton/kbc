import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this._closeHandler = (event) => {
      if (!this.element.contains(event.target)) this._close()
    }
    document.addEventListener("click", this._closeHandler)
  }

  disconnect() {
    document.removeEventListener("click", this._closeHandler)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
  }

  close() { this._close() }

  _close() {
    this.menuTarget.classList.add("hidden")
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["popup"]

  connect() {
    this._closeHandler = (event) => {
      if (!this.element.contains(event.target)) {
        this._hide()
      }
    }
    document.addEventListener("click", this._closeHandler)
  }

  disconnect() {
    document.removeEventListener("click", this._closeHandler)
  }

  toggle(event) {
    if (!this.element.closest(".hex")?.classList.contains("selectable")) return
    event.stopPropagation()
    this.popupTarget.classList.toggle("hidden")
  }

  cancel(event) {
    event.preventDefault()
    event.stopPropagation()
    this._hide()
  }

  _hide() {
    if (this.hasPopupTarget) {
      this.popupTarget.classList.add("hidden")
    }
  }
}

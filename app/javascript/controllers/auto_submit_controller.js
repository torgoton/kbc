import { Controller } from "@hotwired/stimulus"

// Submits the closest form as soon as the input changes.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}

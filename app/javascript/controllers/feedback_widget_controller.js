import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel", "textarea"]

  connect() {
    this.handleEscape = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.handleEscape)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleEscape)
  }

  toggle() {
    if (this.panelTarget.style.display === "none") {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.panelTarget.style.display = "block"
    this.buttonTarget.style.display = "none"
    this.textareaTarget.focus()
  }

  close() {
    this.panelTarget.style.display = "none"
    this.buttonTarget.style.display = "flex"
    this.textareaTarget.value = ""
  }

  handleEscape(event) {
    if (event.key === "Escape" && this.panelTarget.style.display !== "none") {
      this.close()
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["expanded"]

  toggle(event) {
    // Don't toggle if clicking on a button or link
    if (event.target.closest("a, button, form")) return

    this.element.classList.toggle("is-expanded")
  }

  openLightbox(event) {
    event.stopPropagation()
    const img = event.currentTarget
    const src = img.dataset.fullSrc || img.src

    const lightbox = document.createElement("div")
    lightbox.className = "lightbox"
    lightbox.innerHTML = `
      <button class="lightbox-close">&times;</button>
      <img src="${src}" alt="">
    `
    lightbox.addEventListener("click", () => lightbox.remove())
    document.body.appendChild(lightbox)
  }
}

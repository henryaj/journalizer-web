import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "placeholder", "previewContainer", "previewGrid", "costDisplay", "submit", "dropzone", "loading"]

  connect() {
    this.files = new DataTransfer()
    this.currentRotation = 0
  }

  showLoading() {
    this.submitTarget.style.display = "none"
    this.loadingTarget.style.display = "flex"
  }

  handleFiles(event) {
    const newFiles = Array.from(event.target.files)

    newFiles.forEach(file => {
      if (file.type.startsWith('image/')) {
        this.files.items.add(file)
        this.addPreview(file)
      }
    })

    this.updateInput()
    this.updateUI()
  }

  addPreview(file) {
    const reader = new FileReader()
    reader.onload = (e) => {
      const div = document.createElement('div')
      div.className = 'preview-item'
      div.dataset.filename = file.name
      if (this.currentRotation > 0) {
        div.classList.add(`rotated-${this.currentRotation}`)
      }
      div.innerHTML = `
        <img src="${e.target.result}" alt="Preview">
        <button type="button" class="preview-remove" data-action="click->upload#removeFile" data-filename="${file.name}">&times;</button>
      `
      this.previewGridTarget.appendChild(div)
    }
    reader.readAsDataURL(file)
  }

  removeFile(event) {
    event.preventDefault()
    event.stopPropagation()

    const filename = event.target.dataset.filename
    const newFiles = new DataTransfer()

    for (let i = 0; i < this.files.files.length; i++) {
      if (this.files.files[i].name !== filename) {
        newFiles.items.add(this.files.files[i])
      }
    }

    this.files = newFiles
    event.target.closest('.preview-item').remove()
    this.updateInput()
    this.updateUI()
  }

  addMore(event) {
    event.preventDefault()
    event.stopPropagation()
    this.inputTarget.click()
  }

  updateRotation(event) {
    this.currentRotation = parseInt(event.target.value)

    // Update all preview items with new rotation
    const items = this.previewGridTarget.querySelectorAll('.preview-item')
    items.forEach(item => {
      item.classList.remove('rotated-90', 'rotated-180', 'rotated-270')
      if (this.currentRotation > 0) {
        item.classList.add(`rotated-${this.currentRotation}`)
      }
    })
  }

  updateInput() {
    this.inputTarget.files = this.files.files
  }

  updateUI() {
    const count = this.files.files.length

    if (count > 0) {
      this.placeholderTarget.style.display = 'none'
      this.previewContainerTarget.style.display = 'block'
      this.dropzoneTarget.style.cursor = 'default'
      this.inputTarget.style.display = 'none'
      this.costDisplayTarget.textContent = `${count} page(s) = ${count} credit(s)`
      this.submitTarget.disabled = false
    } else {
      this.placeholderTarget.style.display = 'flex'
      this.previewContainerTarget.style.display = 'none'
      this.dropzoneTarget.style.cursor = 'pointer'
      this.inputTarget.style.display = 'block'
      this.costDisplayTarget.textContent = 'Select images to see cost'
      this.submitTarget.disabled = true
    }
  }
}

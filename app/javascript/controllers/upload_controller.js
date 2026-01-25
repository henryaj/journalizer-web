import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "placeholder", "previewGrid", "costDisplay", "submit", "dropzone"]

  connect() {
    this.files = new DataTransfer()
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

  updateInput() {
    this.inputTarget.files = this.files.files
  }

  updateUI() {
    const count = this.files.files.length
    
    if (count > 0) {
      this.placeholderTarget.style.display = 'none'
      this.previewGridTarget.style.display = 'grid'
      this.costDisplayTarget.textContent = `${count} page(s) = ${count} credit(s)`
      this.submitTarget.disabled = false
    } else {
      this.placeholderTarget.style.display = 'flex'
      this.previewGridTarget.style.display = 'none'
      this.costDisplayTarget.textContent = 'Select images to see cost'
      this.submitTarget.disabled = true
    }
  }
}

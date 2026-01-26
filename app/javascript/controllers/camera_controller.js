import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "video", "canvas", "loading", "error", "errorMessage", "controls",
    "strip", "stripInner", "count", "shutter", "flipBtn", "doneBtn",
    "form", "filesContainer", "orientationInput", "orientationBtn", "orientationLabel",
    "flash", "uploading"
  ]

  connect() {
    this.captures = []
    this.currentOrientation = 0
    this.facingMode = "environment"
    this.stream = null

    document.body.classList.add("camera-page")
    this.startCamera()
  }

  disconnect() {
    document.body.classList.remove("camera-page")
    this.stopCamera()
  }

  async startCamera() {
    this.loadingTarget.style.display = "flex"
    this.errorTarget.style.display = "none"

    try {
      const constraints = {
        video: {
          facingMode: this.facingMode,
          width: { ideal: 1920 },
          height: { ideal: 1080 }
        },
        audio: false
      }

      this.stream = await navigator.mediaDevices.getUserMedia(constraints)
      this.videoTarget.srcObject = this.stream
      await this.videoTarget.play()

      this.loadingTarget.style.display = "none"
    } catch (err) {
      console.error("Camera error:", err)
      this.loadingTarget.style.display = "none"
      this.errorTarget.style.display = "flex"
      this.errorMessageTarget.textContent = this.getErrorMessage(err)
    }
  }

  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }
  }

  getErrorMessage(err) {
    if (err.name === "NotAllowedError") {
      return "Camera access denied. Please allow camera access and refresh."
    } else if (err.name === "NotFoundError") {
      return "No camera found on this device."
    } else if (err.name === "NotReadableError") {
      return "Camera is in use by another app."
    }
    return "Could not access camera. Try uploading files instead."
  }

  async flipCamera() {
    this.facingMode = this.facingMode === "environment" ? "user" : "environment"
    this.stopCamera()
    await this.startCamera()
  }

  cycleOrientation() {
    const orientations = [0, 90, 180, 270]
    const currentIndex = orientations.indexOf(this.currentOrientation)
    this.currentOrientation = orientations[(currentIndex + 1) % 4]

    this.orientationLabelTarget.textContent = this.currentOrientation + "°"
    // Don't update orientationInput - rotation is now baked into captured images

    this.orientationBtnTarget.style.transform = "rotate(" + this.currentOrientation + "deg)"
  }

  capture() {
    const video = this.videoTarget
    const canvas = this.canvasTarget
    const ctx = canvas.getContext("2d")
    const rotation = this.currentOrientation

    // For 90/270 rotations, swap width/height
    if (rotation === 90 || rotation === 270) {
      canvas.width = video.videoHeight
      canvas.height = video.videoWidth
    } else {
      canvas.width = video.videoWidth
      canvas.height = video.videoHeight
    }

    // Apply rotation transform
    ctx.save()
    if (rotation === 90) {
      ctx.translate(canvas.width, 0)
      ctx.rotate(Math.PI / 2)
    } else if (rotation === 180) {
      ctx.translate(canvas.width, canvas.height)
      ctx.rotate(Math.PI)
    } else if (rotation === 270) {
      ctx.translate(0, canvas.height)
      ctx.rotate(-Math.PI / 2)
    }
    ctx.drawImage(video, 0, 0)
    ctx.restore()

    const self = this
    canvas.toBlob(function(blob) {
      const filename = "page-" + new Date().getTime() + ".jpg"
      const file = new File([blob], filename, { type: "image/jpeg" })

      self.captures.push({ file: file, dataUrl: canvas.toDataURL("image/jpeg", 0.9) })
      self.updateUI()
    }, "image/jpeg", 0.9)

    // Trigger flash effect
    this.flashTarget.classList.add("flash")
    setTimeout(function() { self.flashTarget.classList.remove("flash") }, 300)
  }

  removeCapture(event) {
    const index = parseInt(event.target.dataset.index)
    this.captures.splice(index, 1)
    this.updateUI()
  }

  updateUI() {
    const count = this.captures.length

    if (count > 0) {
      this.stripTarget.style.display = "flex"
      this.doneBtnTarget.style.visibility = "visible"
      this.countTarget.textContent = count + " page" + (count !== 1 ? "s" : "")

      let html = ""
      for (let i = 0; i < this.captures.length; i++) {
        html += '<div class="strip-item">'
        html += '<img src="' + this.captures[i].dataUrl + '" alt="Page ' + (i + 1) + '">'
        html += '<button type="button" class="strip-remove" data-action="click->camera#removeCapture" data-index="' + i + '">&times;</button>'
        html += '</div>'
      }
      this.stripInnerTarget.innerHTML = html
    } else {
      this.stripTarget.style.display = "none"
      this.doneBtnTarget.style.visibility = "hidden"
    }
  }

  done() {
    if (this.captures.length === 0) return

    // Show uploading overlay
    this.uploadingTarget.style.display = "flex"
    this.controlsTarget.style.display = "none"
    this.stripTarget.style.display = "none"

    const dataTransfer = new DataTransfer()
    for (let i = 0; i < this.captures.length; i++) {
      dataTransfer.items.add(this.captures[i].file)
    }

    const input = document.createElement("input")
    input.type = "file"
    input.name = "images[]"
    input.multiple = true
    input.files = dataTransfer.files
    input.style.display = "none"
    this.filesContainerTarget.appendChild(input)

    this.formTarget.requestSubmit()
  }
}

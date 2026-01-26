import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["grid", "item", "groupsContainer", "groupInputs", "dateParsing", "instructions", "form", "groupBadge"]

  connect() {
    // Map of groupId -> Set of page numbers
    this.groups = new Map()
    this.nextGroupId = 0

    // Initialize each page in its own implicit group
    this.itemTargets.forEach(item => {
      const pageNum = parseInt(item.dataset.pageNumber)
      this.groups.set(this.nextGroupId++, new Set([pageNum]))
    })

    this.updateUI()
  }

  toggleDateParsing() {
    this.updateUI()
  }

  async rotatePage(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.target
    const url = button.dataset.url
    const item = button.closest('[data-review-target="item"]')

    // Disable button during request
    button.disabled = true

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        const data = await response.json()
        const newOrientation = data.orientation

        // Update the item's rotation class
        item.classList.remove('rotated-90', 'rotated-180', 'rotated-270')
        if (newOrientation > 0) {
          item.classList.add(`rotated-${newOrientation}`)
        }
        item.dataset.orientation = newOrientation
      }
    } catch (error) {
      console.error('Failed to rotate:', error)
    } finally {
      button.disabled = false
    }
  }

  dragStart(event) {
    event.target.classList.add('dragging')
    event.dataTransfer.setData('text/plain', event.target.dataset.pageNumber)
    event.dataTransfer.effectAllowed = 'move'
  }

  dragEnd(event) {
    event.target.classList.remove('dragging')
    // Remove all drag-over states
    this.itemTargets.forEach(item => item.classList.remove('drag-over'))
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'

    const target = event.target.closest('[data-review-target="item"]')
    if (target && !target.classList.contains('dragging')) {
      target.classList.add('drag-over')
    }
  }

  drop(event) {
    event.preventDefault()

    const draggedPageNum = parseInt(event.dataTransfer.getData('text/plain'))
    const target = event.target.closest('[data-review-target="item"]')

    if (!target) return

    const targetPageNum = parseInt(target.dataset.pageNumber)
    target.classList.remove('drag-over')

    if (draggedPageNum === targetPageNum) return

    // Find and merge the groups
    this.mergePages(draggedPageNum, targetPageNum)
    this.updateUI()
  }

  mergePages(pageA, pageB) {
    let groupIdA = null
    let groupIdB = null

    // Find which groups these pages belong to
    for (const [groupId, pages] of this.groups) {
      if (pages.has(pageA)) groupIdA = groupId
      if (pages.has(pageB)) groupIdB = groupId
    }

    if (groupIdA === groupIdB) return // Already in same group

    // Merge groupA into groupB
    const pagesA = this.groups.get(groupIdA)
    const pagesB = this.groups.get(groupIdB)

    pagesA.forEach(page => pagesB.add(page))
    this.groups.delete(groupIdA)
  }

  splitPage(event) {
    event.preventDefault()
    const pageNum = parseInt(event.target.dataset.pageNumber)

    // Find the group this page is in
    for (const [groupId, pages] of this.groups) {
      if (pages.has(pageNum) && pages.size > 1) {
        pages.delete(pageNum)
        this.groups.set(this.nextGroupId++, new Set([pageNum]))
        break
      }
    }

    this.updateUI()
  }

  updateUI() {
    this.updateGroupBadges()
    this.updateGroupsDisplay()
    this.updateFormInputs()
  }

  updateGroupBadges() {
    // Create a map of pageNum -> groupId for quick lookup
    const pageToGroup = new Map()
    let groupNum = 1

    for (const [groupId, pages] of this.groups) {
      if (pages.size > 1) {
        pages.forEach(pageNum => pageToGroup.set(pageNum, groupNum))
        groupNum++
      }
    }

    // Update badges on each item
    this.itemTargets.forEach(item => {
      const pageNum = parseInt(item.dataset.pageNumber)
      const badge = item.querySelector('[data-review-target="groupBadge"]')

      if (pageToGroup.has(pageNum)) {
        badge.textContent = `Group ${pageToGroup.get(pageNum)}`
        badge.style.display = 'block'
        item.classList.add('grouped')
      } else {
        badge.textContent = ''
        badge.style.display = 'none'
        item.classList.remove('grouped')
      }
    })
  }

  updateGroupsDisplay() {
    const container = this.groupsContainerTarget
    container.innerHTML = ''

    // Show groups with more than 1 page
    let groupNum = 1
    for (const [groupId, pages] of this.groups) {
      if (pages.size > 1) {
        const sortedPages = Array.from(pages).sort((a, b) => a - b)
        const div = document.createElement('div')
        div.className = 'review-group-display'
        div.innerHTML = `
          <span class="group-label">Group ${groupNum}:</span>
          <span class="group-pages">Pages ${sortedPages.join(', ')}</span>
          <span class="group-note">(will become one entry)</span>
          ${sortedPages.map(p => `
            <button type="button" class="btn btn-small btn-ghost" data-action="click->review#splitPage" data-page-number="${p}">
              Remove page ${p}
            </button>
          `).join('')}
        `
        container.appendChild(div)
        groupNum++
      }
    }

    if (groupNum === 1) {
      container.innerHTML = '<p class="review-no-groups">No pages grouped. Each page will become a separate entry.</p>'
    }
  }

  updateFormInputs() {
    let html = ''
    let groupNum = 0

    for (const [groupId, pages] of this.groups) {
      const sortedPages = Array.from(pages).sort((a, b) => a - b)
      sortedPages.forEach(pageNum => {
        html += `<input type="hidden" name="groups[${groupNum}][]" value="${pageNum}">`
      })
      groupNum++
    }

    this.groupInputsTarget.innerHTML = html
  }
}

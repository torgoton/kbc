import { Controller } from "@hotwired/stimulus"

const MINIMIZED_KEY = "kbc_chat_minimized"
const CHAT_FLEX_KEY = "kbc_chat_flex"

export default class extends Controller {
  static targets = ["log", "divider", "panel", "messages", "composer", "input", "badge"]

  connect() {
    this.unreadCount = 0
    this._pendingChatMessages = 0
    this._restoreMinimized()
    this._restoreSplit()
    this._scheduleCloseTimer()

    this._streamHandler = (event) => {
      if (event.target?.target !== "chat-messages") return
      this._pendingChatMessages += 1
      clearTimeout(this._streamDebounce)
      this._streamDebounce = setTimeout(() => this._onStreamSettled(), 50)
    }
    document.addEventListener("turbo:before-stream-render", this._streamHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this._streamHandler)
    clearTimeout(this._streamDebounce)
    clearTimeout(this._closeTimer)
  }

  toggleMinimize() {
    const minimized = this.panelTarget.classList.toggle("minimized")
    localStorage.setItem(MINIMIZED_KEY, minimized)
    if (!minimized) this._clearBadge()
  }

  clearInput() {
    if (this.hasInputTarget) this.inputTarget.value = ""
  }

  startDrag(event) {
    event.preventDefault()
    const container = this.element
    const onMove = (moveEvent) => {
      const rect = container.getBoundingClientRect()
      const offset = moveEvent.clientY - rect.top
      const logFlex = Math.min(Math.max(offset, 40), rect.height - 40)
      const chatFlex = rect.height - logFlex
      container.style.setProperty("--log-flex", logFlex)
      container.style.setProperty("--chat-flex", chatFlex)
    }
    const onUp = () => {
      document.removeEventListener("mousemove", onMove)
      document.removeEventListener("mouseup", onUp)
      localStorage.setItem(CHAT_FLEX_KEY, JSON.stringify({
        log: container.style.getPropertyValue("--log-flex"),
        chat: container.style.getPropertyValue("--chat-flex")
      }))
    }
    document.addEventListener("mousemove", onMove)
    document.addEventListener("mouseup", onUp)
  }

  _restoreMinimized() {
    if (localStorage.getItem(MINIMIZED_KEY) === "true") {
      this.panelTarget.classList.add("minimized")
    }
  }

  _restoreSplit() {
    const saved = localStorage.getItem(CHAT_FLEX_KEY)
    if (!saved) return
    try {
      const { log, chat } = JSON.parse(saved)
      if (log) this.element.style.setProperty("--log-flex", log)
      if (chat) this.element.style.setProperty("--chat-flex", chat)
    } catch (e) {
      // ponytail: malformed localStorage value, fall back to default split
    }
  }

  _onStreamSettled() {
    const newMessages = this._pendingChatMessages
    this._pendingChatMessages = 0
    if (newMessages === 0) return

    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
    if (this.panelTarget.classList.contains("minimized")) {
      this.unreadCount += newMessages
      this._showBadge()
    }
  }

  _showBadge() {
    if (!this.hasBadgeTarget) return
    this.badgeTarget.textContent = this.unreadCount
    this.badgeTarget.classList.remove("hidden")
  }

  _clearBadge() {
    this.unreadCount = 0
    if (this.hasBadgeTarget) this.badgeTarget.classList.add("hidden")
  }

  _scheduleCloseTimer() {
    if (!this.hasComposerTarget) return
    const closeAt = this.composerTarget.dataset.chatCloseAt
    if (!closeAt) return
    const delay = Math.max(0, closeAt * 1000 - Date.now())
    this._closeTimer = setTimeout(() => {
      this.composerTarget.innerHTML = '<p class="chat-closed-note">Chat closed</p>'
    }, delay)
  }
}

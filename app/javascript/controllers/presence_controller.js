import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Reports that this page is open. kind "site" (every page) drives the online
// dots; kind "dashboard" (dashboard page only) lists the user's real-time
// table. Each page gets its own connection id so several tabs count correctly.
// Heartbeats keep the server-side Presence row fresh; see PresenceChannel.
const HEARTBEAT_INTERVAL_MS = 30_000

export default class extends Controller {
  static values = { kind: { type: String, default: "site" } }

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "PresenceChannel", kind: this.kindValue, connection_id: crypto.randomUUID() }
    )
    this.heartbeat = setInterval(() => this.subscription.perform("ping"), HEARTBEAT_INTERVAL_MS)
  }

  disconnect() {
    clearInterval(this.heartbeat)
    this.consumer?.disconnect()
  }
}

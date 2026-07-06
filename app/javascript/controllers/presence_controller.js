import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Keeps users.last_seen_at fresh while this tab is open, so User#online?
// (last_seen_at within the last minute) reflects reality. Subscribing and
// each heartbeat touch the timestamp server-side; see PresenceChannel.
const HEARTBEAT_INTERVAL_MS = 30_000

export default class extends Controller {
  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create("PresenceChannel")
    this.heartbeat = setInterval(() => this.subscription.perform("ping"), HEARTBEAT_INTERVAL_MS)
  }

  disconnect() {
    clearInterval(this.heartbeat)
    this.consumer?.disconnect()
  }
}

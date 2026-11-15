# == Schema Information
#
# Table name: users
#
#  id                :bigint           not null, primary key
#  admin             :boolean          default(FALSE), not null
#  approved          :boolean          default(FALSE)
#  dashboard_seen_at :datetime
#  email_address     :string           not null
#  handle            :string           not null
#  last_seen_at      :datetime
#  password_digest   :string           not null
#  rating            :integer          default(1500), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_users_on_email_address  (email_address) UNIQUE
#  index_users_on_handle         (handle) UNIQUE
#
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :presences, dependent: :delete_all

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  has_many :game_players
  has_many :games, through: :game_players

  validates :email_address, presence: true
  validates :handle, presence: true, uniqueness: true
  validates :password, presence: true, on: :create

  def my_games
    games.where(state: [ "playing", "waiting" ]).order(realtime: :desc, created_at: :asc, id: :asc)
  end

  # Open tables I could join (not real time), skipping ones reserved for someone else.
  def waiting_games
    open_tables.where(realtime: false)
  end

  # Open real-time tables I could join right now: the creator must be on the
  # dashboard and not already busy in a playing real-time game (that hides
  # their other tables until it ends).
  def realtime_waiting_games
    open_tables.where(realtime: true).select { |game| game.joinable_by?(self) }
  end

  def in_realtime_game?
    games.playing.where(realtime: true).exists?
  end

  def on_dashboard?
    Presence.online?(id, "dashboard")
  end

  def completed_games
    games.completed.order(updated_at: :desc, id: :desc)
  end

  def rated_games_count
    game_players.where.not(rating_after: nil).count
  end

  def online?
    Presence.online?(id, "site")
  end

  private

  def open_tables
    Game.waiting.where(invited_user_id: [ nil, id ])
      .where.not(id: game_players.select(:game_id))
      .includes(game_players: :player)
      .order(created_at: :asc, id: :asc)
  end
end

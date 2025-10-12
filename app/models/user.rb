# == Schema Information
#
# Table name: users
#
#  id              :bigint           not null, primary key
#  approved        :boolean          default(FALSE)
#  email_address   :string           not null
#  handle          :string           not null
#  password_digest :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_users_on_email_address  (email_address) UNIQUE
#  index_users_on_handle         (handle) UNIQUE
#
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  has_many :game_players
  has_many :games, through: :game_players

  validates :email_address, presence: true
  validates :handle, presence: true, uniqueness: true
  validates :password, presence: true, on: :create
end

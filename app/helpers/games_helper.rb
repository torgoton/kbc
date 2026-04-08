module GamesHelper
  FIXED_SOUND_KEYS = %w[
    build
    end_turn
    game_end
    move
    my_turn
    select_settlement
    tile_forfeit
    tile_pickup
    undo
  ].freeze

  # Returns the list of sound keys to preload for this game:
  # always the 9 fixed event sounds, plus one key per tile type in play.
  # game.boards is an array of [board_name, rotation] pairs, e.g. [["Tavern", 0], ["Paddock", 1]].
  def sound_preload_keys(game)
    tile_keys = game.boards.map { |name, _| name.downcase }
    (FIXED_SOUND_KEYS + tile_keys).uniq
  end

  # Returns a hash of { sound_key => fingerprinted_asset_path } for all keys
  # whose .ogg file exists in app/assets/sounds/. Silently skips missing files
  # so the game works before all recordings are in place.
  def sound_asset_paths(keys)
    keys.each_with_object({}) do |k, hash|
      hash[k] = asset_path("#{k}.ogg")
    rescue StandardError
      # File not yet added to app/assets/sounds/ — JS will skip unknown keys
    end
  end
end

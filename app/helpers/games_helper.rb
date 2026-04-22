module GamesHelper
  PLAYER_COLORS = %w[#ffcc00 #0055d4 #e63946 #2dc653 #9b59b6].freeze

  def player_color(order)
    PLAYER_COLORS[order] || "#888888"
  end

  def sound_paths
    Dir[Rails.root.join("app/assets/sounds/*.ogg")].each_with_object({}) do |f, h|
      name = File.basename(f, ".ogg")
      h[name] = asset_path(File.basename(f))
    end
  end
end

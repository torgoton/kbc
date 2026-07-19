module GamesHelper
  PLAYER_COLORS = %w[#ffcc00 #0055d4 #e63946 #2dc653 #9b59b6].freeze

  def player_color(order)
    PLAYER_COLORS[order] || "#888888"
  end

  # Initial clock text, server-rendered so the span isn't empty (and invisible)
  # until clock_controller connects. Must match the JS render() format exactly;
  # the controller overwrites this on connect and keeps ticking.
  def clock_display(ms)
    total_seconds = ms.abs / 1000
    format("%s%d:%02d", ms.negative? ? "-" : "", total_seconds / 60, total_seconds % 60)
  end

  def sound_paths
    @sound_paths ||= Dir[Rails.root.join("app/assets/sounds/*.ogg")].each_with_object({}) do |f, h|
      name = File.basename(f, ".ogg")
      h[name] = asset_path(File.basename(f))
    end
  end
end

module GamesHelper
  PLAYER_COLORS = %w[#ffcc00 #0055d4 #e63946 #2dc653 #9b59b6].freeze

  def player_color(order)
    PLAYER_COLORS[order] || "#888888"
  end

  SPARK_W = 200
  SPARK_H = 50
  SPARK_PAD = 2

  # Inline-SVG line chart of each player's score at the end of every round.
  # Every line starts from 0; the top is the highest score so far. Nil until a round completes.
  def score_sparkline(game)
    history = game.score_history
    return if history.empty?

    rows = [ history.first.transform_values { 0 } ] + history
    top = [ rows.flat_map { |r| r.values }.max, 1 ].max
    x_step = (SPARK_W - 2 * SPARK_PAD).fdiv(rows.size - 1)
    lines = game.game_players.sort_by(&:order).map do |gp|
      points = rows.each_with_index.map do |row, i|
        y = SPARK_H - SPARK_PAD - row[gp.order.to_s].to_f / top * (SPARK_H - 2 * SPARK_PAD)
        "#{(SPARK_PAD + i * x_step).round(1)},#{y.round(1)}"
      end
      tag.polyline(points: points.join(" "), fill: "none", stroke: player_color(gp.order),
                   "stroke-width": 2, "vector-effect": "non-scaling-stroke")
    end
    tag.svg(safe_join(lines), class: "score-sparkline", viewBox: "0 0 #{SPARK_W} #{SPARK_H}",
            preserveAspectRatio: "none", role: "img", "aria-label": "Score by round")
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

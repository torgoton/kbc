module Boards
  # The Emperor's Choice "Island" decree: a 7x9 map (X = sea rim, space = void) off to the side of
  # the main 20x20 board. Map row 0 / col 0 sit at board row ROW / col COL, so the playable 5x7
  # (map rows 1-5, cols 1-7) is rows 21-25, cols 0-6, and a map row keeps the parity of its board row.
  class Island
    ROW = 20
    COL = -1
    SEA = "X".freeze

    SECTIONS = [
      # 0: Front
      {
        map: [
          "  XXXXX  ",
          " XGGGGXX ",
          " XSWGGTTX",
          "XDWGGLTTX",
          " XDDDTTXX",
          " XXDDTX  ",
          "   XXXX  "
        ],
        silver_hexes: [
          { r: 2, c: 2, k: "Castle" }
        ],
        location_hexes: [
          { r: 3, c: 5, k: "RopeBridge" }
        ]
      },
      # 1: Back
      {
        map: [
          "   XXXXX ",
          " XXGGFFX ",
          " XMGGLFFX",
          "XDDGMMFFX",
          " XXDDSDFX",
          "  XDDDXX ",
          "   XXXX  "
        ],
        silver_hexes: [
          { r: 4, c: 5, k: "Castle" }
        ],
        location_hexes: [
          { r: 2, c: 5, k: "TreeHouse" }
        ]
      }
    ].freeze

    attr_reader :id

    def initialize(id)
      @id = id
      @data = SECTIONS.fetch(id)
    end

    def map = @data[:map]
    def rows = map.size
    def cols = map.first.size

    # Letter at a board position; "" for the void and anywhere off the island.
    def terrain_at(row, col)
      r, c = row - ROW, col - COL
      return "" unless r.between?(0, rows - 1) && c.between?(0, cols - 1)
      map[r][c].strip
    end

    # The hexes that can be played on (not sea, not void), row-major.
    def cells
      @cells ||= (0...rows).flat_map do |r|
        (0...cols).filter_map { |c| [ ROW + r, COL + c ] unless [ " ", SEA ].include?(map[r][c]) }
      end
    end

    def silver_hex_kind(row, col)
      silver_hexes.find { |h| h[:r] == row && h[:c] == col }&.dig(:k)
    end

    def silver_hex_css_class(row, col) = BoardSection::SILVER_HEX_KINDS.dig(silver_hex_kind(row, col), :css_class)
    def silver_hex_description(row, col) = BoardSection::SILVER_HEX_KINDS.dig(silver_hex_kind(row, col), :description)

    def silver_hexes = to_board(@data[:silver_hexes])
    def location_hexes = to_board(@data[:location_hexes])

    private

    def to_board(hexes) = hexes.map { |h| h.merge(r: ROW + h[:r], c: COL + h[:c]) }
  end
end

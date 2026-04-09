module Boards
  class GardenBoard < BoardSection
    def map
      [
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        ""
      ]
    end

    def raw_scoring_hexes
      [
        { r: 7, c: 6, k: "Nomad" }
      ]
    end

    def raw_location_hexes
      [
        { r: 2, c: 5, k: "Garden" },
        { r: 6, c: 3, k: "Garden" }
      ]
    end
  end
end

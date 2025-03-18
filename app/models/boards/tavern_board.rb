module Boards
  class TavernBoard < BoardSection
    def map
      [
        "FDDMMDDCCC",
        "FFDDDMMCCC",
        "FFFFFFFMMM",
        "WWFSGGTTMM",
        "FFWWGGGTTC",
        "FCCWGTTCCC",
        "DFLCWTTLCG",
        "DDCWTTGGGG",
        "DDDWTTTGGG",
        "DDWWTTTGGG"
      ]
    end

    def silver_hexes
      [
        { r: 3, c: 3, k: "Castle" }
      ]
    end

    def location_hexes
      [
        { r: 6, c: 2, k: "Tavern" },
        { r: 6, c: 7, k: "Tavern" }
      ]
    end
  end
end

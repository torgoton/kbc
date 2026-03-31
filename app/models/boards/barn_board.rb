module Boards
  class BarnBoard < BoardSection
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

    def scoring_hexes
      [
        { r: 7, c: 7, k: "Castle" }
      ]
    end

    def location_hexes
      [
        { r: 2, c: 6, k: "Barn" },
        { r: 6, c: 2, k: "Barn" }
      ]
    end
  end
end

module Boards
  class GardenBoard < BoardSection
    def map
      [
        "CCCWWWWDDD",
        "CCCWLFDDMD",
        "CCCCCCFDMD",
        "CGGCCMFMDD",
        "CGGGDMMFFF",
        "TFGLDDFFFF",
        "TTFFDMFGGF",
        "TTMFMTSGGG",
        "TMTTTTWWGG",
        "TTTTWWWGGG"
      ]
    end

    def raw_scoring_hexes
      [
        { r: 7, c: 6, k: "Nomad" }
      ]
    end

    def raw_location_hexes
      [
        { r: 1, c: 4, k: "Garden" },
        { r: 5, c: 3, k: "Garden" }
      ]
    end
  end
end

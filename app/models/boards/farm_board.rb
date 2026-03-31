module Boards
  class FarmBoard < Boards::BoardSection
    def map
      [
        "DDCWWTTTGG",
        "DSCWTTTLGG",
        "CCCFFFTCFF",
        "CCFFWDDCCF",
        "CGGWFFDDCC",
        "GGLFWFWDDC",
        "GGGTFFWWDD",
        "GGTTMWWWDW",
        "GMTTWWWWWW",
        "TTTWWWWWWW"
      ]
    end

    def raw_scoring_hexes
      [
        { r: 1, c: 1, k: "Castle" }
      ]
    end

    def raw_location_hexes
      [
        { r: 1, c: 7, k: "Farm" },
        { r: 5, c: 2, k: "Farm" }
      ]
    end
  end
end

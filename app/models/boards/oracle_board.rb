module Boards
  class OracleBoard < Boards::BoardSection
    def map
      [
        "GGGTTWGTTT",
        "GGGSTWGTTT",
        "GFFGTTWGGT",
        "FFCGTWFLTT",
        "FFFCCWFFWW",
        "MMCGGWWWDD",
        "CCCMGFFFDD",
        "CCSDMDFFCC",
        "WWWDDDDMCC",
        "WWWWDDDDDC"
      ]
    end

    def scoring_hexes
      [
        { r: 1, c: 3, k: "Castle" },
        { r: 7, c: 2, k: "Castle" }
      ]
    end

    def location_hexes
      [
        { r: 3, c: 7, k: "Oracle" }
      ]
    end
  end
end

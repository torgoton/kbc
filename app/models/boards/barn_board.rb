module Boards
  class BarnBoard < BoardSection
    def map
      [
        "CDDDDDDDDD",
        "CCCDDDDDCD",
        "MMMDMMLDDC",
        "CMMMMMFFCC",
        "CCCMMWFFFC",
        "GCCCMFFWTC",
        "GGLTTFWFFT",
        "GGTTFFGSTT",
        "GGGTTWGGTT",
        "GGGTWGGTTT"
      ]
    end

    def raw_silver_hexes
      [
        { r: 7, c: 7, k: "Castle" }
      ]
    end

    def raw_location_hexes
      [
        { r: 2, c: 6, k: "Barn" },
        { r: 6, c: 2, k: "Barn" }
      ]
    end
  end
end

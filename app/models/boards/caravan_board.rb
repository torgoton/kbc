module Boards
  class CaravanBoard < BoardSection
    def map
      [
        "WWGGWWWFFF",
        "WGGTWWWFFF",
        "WWWGTWWDDF",
        "TTWSTWDMFF",
        "TTTWWWDDGG",
        "TTTTCDGGGG",
        "TTLCCCGGMG",
        "TCCCCGLDDG",
        "CMCCCFFFDD",
        "CCCFFFFDDD"
      ]
    end

    def raw_scoring_hexes
      [
        { r: 3, c: 3, k: "Nomad" }
      ]
    end

    def raw_location_hexes
      [
        { r: 6, c: 2, k: "Caravan" },
        { r: 7, c: 6, k: "Caravan" }
      ]
    end
  end
end

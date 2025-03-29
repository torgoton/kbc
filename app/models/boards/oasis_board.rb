module Boards
  class OasisBoard < Boards::BoardSection
    def map
      [
        "DDCWWTTGGG",
        "DCWFFTTTGG",
        "DDWFFTTLFG",
        "WWWFGTGGGG",
        "WWWWGGGGFF",
        "WTTWGGCCDC",
        "WTCTWGCCDC",
        "WSCFWLDDCW",
        "WWCFWWWDDW",
        "WWWWWWWWWW"
      ]
    end

    def silver_hexes
      [
        { r: 7, c: 1, k: "Castle" }
      ]
    end

    def location_hexes
      [
        { r: 2, c: 7, k: "OasisTile" },
        { r: 7, c: 5, k: "OasisTile" }
      ]
    end
  end
end

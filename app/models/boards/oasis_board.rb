module Boards
  class OasisBoard < Boards::BoardSection
    def map
      [
        "DDCWWTTGGG",
        "DCWFFTTTGG",
        "DDWFFTTLFG",
        "WWWFGTFFFF",
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
        { r: 2, c: 7, k: "Oasis" },
        { r: 7, c: 5, k: "Oasis" }
      ]
    end
  end
end

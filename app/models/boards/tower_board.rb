module Boards
  class TowerBoard < BoardSection
    def map
      [
        "TTTTMMGMCC",
        "TMTTFGMMMC",
        "FFTFFFGGWM",
        "DFFFWLGWMM",
        "DDDDFWGWCC",
        "DCDDDWWCGC",
        "DDCDDWFSGC",
        "CCLDWFFFGG",
        "DCWWWTTFGG",
        "DCCWTTTGGG"
      ]
    end

    def raw_scoring_hexes
      [
        { r: 6, c: 7, k: "Castle" }
      ]
    end

    def raw_location_hexes
      [
        { r: 3, c: 5, k: "Tower" },
        { r: 7, c: 2, k: "Tower" }
      ]
    end
  end
end

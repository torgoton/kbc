module Boards
  class HarborBoard < Boards::BoardSection
    def map
      [
        "GGTTTWGTTF",
        "GFTTWGTTFF",
        "GFFTWGGFFF",
        "FFTTWGMFDD",
        "CFSTWGDDDD",
        "CCTWGGMMDD",
        "CCWWWGDDDC",
        "WWGGWWLCMC",
        "WDSGWMWCCC",
        "WDDWWWWCCC"
      ]
    end

    def scoring_hexes
      [
        { r: 4, c: 2, k: "Castle" },
        { r: 8, c: 2, k: "Castle" }
      ]
    end

    def location_hexes
      [
        { r: 7, c: 6, k: "Harbor" }
      ]
    end
  end
end

module Boards
  class VillageBoard < BoardSection
    def map
      [
        "DDDDDDDGGG",
        "DDDMDFFFGG",
        "DMDDDFWFGT",
        "CFWDSWFTTT",
        "CFFWWWFLCT",
        "CFFFWWFCCC",
        "CCCLTWWFMC",
        "GCGGTWFCCC",
        "GGGGTTTTCM",
        "GGGTTTTTMM"
      ]
    end

    def raw_scoring_hexes
      [
        { r: 3, c: 4, k: "Nomad" }
      ]
    end

    def raw_location_hexes
      [
        { r: 4, c: 7, k: "Village" },
        { r: 6, c: 3, k: "Village" }
      ]
    end
  end
end

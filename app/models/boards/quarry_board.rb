module Boards
  class QuarryBoard < BoardSection
    def map
      [
        "GGGWWWMCCC",
        "GGWTDWWWCC",
        "GMWTLDDDWM",
        "FWTTCCDFFF",
        "FWGGCCDDMF",
        "FWSGCCDSFF",
        "FFWGCCCFFF",
        "DWGGCSTTFF",
        "DDWWGTTMTT",
        "DDDWWTMTTT"
      ]
    end

    def raw_silver_hexes
      [
        { r: 5, c: 2, k: "Nomad" },
        { r: 5, c: 7, k: "Nomad" },
        { r: 7, c: 5, k: "Nomad" }
      ]
    end

    def raw_location_hexes
      [
        { r: 2, c: 4, k: "Quarry" }
      ]
    end
  end
end

module Boards
  class PaddockBoard < Boards::BoardSection
    def map
      [
        "CCCDDWDDDD",
        "MMCDDWDDDD",
        "MMCMMWDDLF",
        "MCMMWMDFFF",
        "CCTTWMMCFF",
        "CTTWCCCMFF",
        "CLTTWFFFFF",
        "GGTWGSGFGT",
        "GGTTWGGGGT",
        "GGTTWGGGTT"
      ]
    end

    def silver_hexes
      [
        { r: 7, c: 5, k: "Castle" }
      ]
    end

    def location_hexes
      [
        { r: 2, c: 8, k: "PaddockTile" },
        { r: 6, c: 1, k: "PaddockTile" }
      ]
    end
  end
end

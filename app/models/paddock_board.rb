class PaddockBoard < BoardSection
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

  def tile_locations
    [
      [ 2, 8 ],
      [ 6, 1 ]
    ]
  end
end

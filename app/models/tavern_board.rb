class TavernBoard < BoardSection
  def map
    [
      "FDDMMDDCCC",
      "FFDDDMMCCC",
      "FFFFFFFMMM",
      "WWFSGGTTMM",
      "FFWWGGGTTC",
      "FCCWGTTCCC",
      "DFLCWTTLCG",
      "DDCWTTGGGG",
      "DDDWTTTGGG",
      "DDWWTTTGGG"
    ]
  end

  def tile_locations
    [
      [ 6, 2 ],
      [ 6, 7 ]
    ]
  end

  def tile_class
    TavernTile
  end
end

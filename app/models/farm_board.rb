class FarmBoard < BoardSection
  def map
    [
      "DDCWWTTTGG",
      "DSCWTTTLGG",
      "CCCFFFTCFF",
      "CCFFWDDCCF",
      "CGGWFFDDCC",
      "GGLFWFWDDC",
      "GGGTFFWWDD",
      "GGTTMWWWDW",
      "GMTTWWWWWW",
      "TTTWWWWWWW"
    ]
  end

  def tile_locations
    [
      [ 1, 7 ],
      [ 5, 2 ]
    ]
  end
end

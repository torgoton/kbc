class OasisBoard < BoardSection
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

  def tile_locations
    [
      [ 2, 7 ],
      [ 7, 5 ]
    ]
  end
end

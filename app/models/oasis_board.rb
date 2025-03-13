class OasisBoard < BoardSection
  MAP = [
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

  def initialize(flipped)
    if flipped == 0
      @terrain = MAP
      @content = [
        [ 6, 2, [ tiles ] ],
        [ 6, 7, [ tiles ] ]
      ]
    else
      @terrain = MAP.reverse.map(&:reverse)
      @content = [
        [ 3, 2, [ tiles ] ],
        [ 3, 7, [ tiles ] ]
      ]
    end
  end

  private

  def tiles
    [
      TavernTile.new,
      TavernTile.new
    ]
  end
end

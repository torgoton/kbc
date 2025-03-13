class FarmBoard < BoardSection
  MAP = [
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

  def initialize(flipped)
    if flipped == 0
      @terrain = MAP
      @content = [
        [ 1, 7, [ tiles ] ],
        [ 5, 2, [ tiles ] ]
      ]
    else
      @terrain = MAP.reverse.map(&:reverse)
      @content = [
        [ 4, 7, [ tiles ] ],
        [ 8, 2, [ tiles ] ]
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

class PaddockBoard < BoardSection
  MAP = [
    "DDCWWTTGGG",
    "DCWFFTTTGG",
    "DDWFFTTLFG",
    "WWWFGTFFFF",
    "WWWWGGGGFF",
    "WTTWGGCCDC",
    "WTCTWGCCDC",
    "WSCFWLDDCW",
    "WWCFWWWDDW",
    "WWWWWWWWWW"
  ]

  def initialize(flipped)
    if flipped == 0
      @terrain = MAP
      @content = [
        [ 2, 7, [ tiles ] ],
        [ 7, 5, [ tiles ] ]
      ]
    else
      @terrain = MAP.reverse.map(&:reverse)
      @content = [
        [ 2, 4, [ tiles ] ],
        [ 7, 2, [ tiles ] ]
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

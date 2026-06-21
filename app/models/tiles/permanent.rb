module Tiles
  class Permanent < Tiles::Tile
    def class_description = "Usable every turn for the entire game".freeze
    def tile_description = "should be overridden".freeze
  end
end

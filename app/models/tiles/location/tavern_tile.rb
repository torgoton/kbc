module Tiles
  class Location
    class TavernTile < Tiles::Location
      CREATOR = "Icon by Hendi Perkasa".freeze
      DESCRIPTION = "Build at one end of a line of at least 3 of your " \
                    "settlements, on a hex that is eligible " \
                    "for building.".freeze

      def builds_settlement? = true

      def action_message(player_handle:, terrain_names:, hand: nil)
        "#{player_handle} must build at the end of a row"
      end

      # Each pair is [forward_dir, backward_dir]; each dir is [even_row_step, odd_row_step].
      DIRECTION_PAIRS = [
        [ [ [ 0,  1 ], [ 0,  1 ] ], [ [ 0, -1 ], [ 0, -1 ] ] ],  # E / W
        [ [ [ -1, -1 ], [ -1, 0 ] ], [ [ 1, 0 ],  [ 1, 1 ] ] ],  # NW / SE
        [ [ [ -1, 0 ], [ -1, 1 ] ], [ [ 1, -1 ], [ 1, 0 ] ] ]    # NE / SW
      ].freeze

      def valid_destinations(from_row: nil, from_col: nil, board_contents:, player_order:, hand: nil)
        settlements = board_contents.settlements_for(player_order).to_set
        candidates = []

        DIRECTION_PAIRS.each do |fwd, bwd|
          settlements.each do |r, c|
            # Only process start-of-run (no settlement one step back)
            br, bc = step(r, c, bwd)
            next if settlements.include?([ br, bc ])

            # Walk forward collecting consecutive settlements
            run_end_r, run_end_c = r, c
            nr, nc = step(r, c, fwd)
            run_length = 1
            while settlements.include?([ nr, nc ])
              run_end_r, run_end_c = nr, nc
              nr, nc = step(nr, nc, fwd)
              run_length += 1
            end

            next if run_length < 3

            candidates << [ nr, nc ] if valid_build?(nr, nc, board_contents)
            candidates << [ br, bc ] if valid_build?(br, bc, board_contents)
          end
        end

        candidates.uniq
      end

      def activatable?(player_order:, board_contents:, hand: nil, supply: Hash.new(0))
        valid_destinations(board_contents:, player_order:).any?
      end

      private

      def step(r, c, dir)
        dr, dc = dir[r % 2]
        [ r + dr, c + dc ]
      end

      def valid_build?(r, c, board_contents)
        (0..19).cover?(r) && (0..19).cover?(c) &&
          board_contents.available_for_building?(r, c) &&
          BUILDABLE_TERRAIN.include?(board_contents.terrain_at(r, c))
      end
    end
  end
end

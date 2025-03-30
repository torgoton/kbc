## Moves

Games should has_many :moves.
Moves need to be "undo"-able
A Move can be
 o build - player at location
 o move - player from one place to other place

belongs_to :game_player
belongs_to :game

order field
committed field - after end of turn, moves cannot be undone

once the mandatory part has begun, it must continue until done

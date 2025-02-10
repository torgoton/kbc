import { BoardTavern } from './board_tavern';
import { BoardPaddock } from './board_paddock';
import { BoardOasis } from './board_oasis';
import { BoardFarm } from './board_farm';

export class Board {
    constructor(G) {
        if (G == null) {
            this.data = {
                boardSections: [
                    [ new BoardTavern().data, new BoardPaddock().data ],
                    [ new BoardOasis().data,  new BoardFarm().data    ]
                ]
            };
        }
        else {
            this.data = {
                boardSections: [
                    [ new BoardTavern(G.board.boardSections[0][0].data), new BoardPaddock(G.board.boardSections[0][0].data) ],
                    [ new BoardOasis(G.board.boardSections[0][0].data),  new BoardFarm(G.board.boardSections[0][0].data)    ]
                ]
            }
        }
    };

    terrainAt(x, y) {
        return this.data.boardSections[Math.floor(y / 10)][Math.floor(x / 10)].terrainAt(x % 10, y % 10);
    };
};

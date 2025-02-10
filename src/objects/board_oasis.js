import { BoardSection } from './board_section';

export class BoardOasis extends BoardSection {
    constructor () {
        super();
        // Canyon Desert Flowers Grassland Location Mountain Silver/Castle Timberland Water
        this.terrainString =   `DDCWWTTGGG
                                DCWFFTTTGG
                                DDWFFTTLFG
                                WWWFGTFFFF
                                WWWWGGGGFF
                                WTTWGGCCDC
                                WTCTWGCCDC
                                WSCFWLDDCW
                                WWCFWWWDDW
                                WWWWWWWWWW`;
        this.fillTerrain();
        this.data.castles = [{ x: 1, y: 7}];
        this.data.locationTiles = [
            { x: 7, y: 2, n: 2},
            { x: 5, y: 7, n: 2}
        ];
        this.data.tokens = [];
    };
};

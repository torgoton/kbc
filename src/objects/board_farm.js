import { BoardSection } from './board_section';

export class BoardFarm extends BoardSection {
    constructor () {
        super();
        // Canyon Desert Flowers Grassland Location Mountain Silver/Castle Timberland Water
        this.terrainString =   `DDCCWTTTGG
                                DSCWTTTLGG
                                CCCFFFTCFF
                                CCFFWDDCCF
                                CGGWFFDDCC
                                GGLFWFWDDC
                                GGGTFFWWDD
                                GGTTMWWWDW
                                GMTTWWWWWW
                                TTTWWWWWWW`;
        this.fillTerrain();
        this.data.castles = [{ x: 1, y: 1}];
        this.data.locationTiles = [
            { x: 7, y: 1, n: 2},
            { x: 2, y: 5, n: 2}
        ];
        this.data.tokens = [];
    };
};

import { BoardSection } from './board_section';

export class BoardPaddock extends BoardSection {
    constructor () {
        super();
        // Canyon Desert Flowers Grassland Location Mountain Silver/Castle Timberland Water
        this.terrainString =   `CCCDDWDDDD
                                MMCDDWDDDD
                                MMCMMWDDLF
                                MMCMMWDDLF
                                CCTTWMMCFF
                                CTTWCCCMFF
                                CLTTWFFFFF
                                GGTWGSGFGT
                                GGTTWGGGGT
                                GGTTWGGGTT`;
        this.fillTerrain();
        this.data.castles = [{ x: 5, y: 7}];
        this.data.locationTiles = [
            { x: 8, y: 2, n: 2},
            { x: 1, y: 6, n: 2}
        ];
        this.data.tokens = [];
    };
};

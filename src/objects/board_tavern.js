import { BoardSection } from './board_section';

export class BoardTavern extends BoardSection {
    constructor () {
        console.log("Constructing BoardTavern");
        super();
        console.log("BrdTav populating");
        this.data.name = "Tavern";
        // Canyon Desert Flowers Grassland Location Mountain Silver/Castle Timberland Water
        this.terrainString =   `FDDMMDDCCC
                                FFDDDMMCCC
                                FFFFFFFMMM
                                WWFSGGTTMM
                                FFWWGGGTTC
                                FCCWGTTCCC
                                DFLCWTTLCG
                                DDCWTTGGGG
                                DDDWTTTGGG
                                DDWWTTTGGG`;
        this.fillTerrain();
        this.data.castles = [{ x: 3, y: 3}];
        this.data.locationTiles = [
            { x: 2, y: 6, n: 2},
            { x: 7, y: 6, n: 2}
        ];
        this.data.tokens = [];
    };
};

export class BoardSection {
    constructor() {
        this.data = {
            name: "",
            terrain: [],
            castles: [],
            locationTiles: [],
            contents: []
        };
        this.terrainString = "";
    };

    fillTerrain() {
        let rows = this.terrainString.split("\n");
        rows.forEach(row => {
            this.data.terrain.push(
                Array.from(row.trim())
            )
        });
    };

    terrainAt(x, y) {
        return this.data.terrain[y][x];
    };
}

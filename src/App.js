import { Client } from 'boardgame.io/client';
import { KBC } from './Game';
import { Board } from './objects/board';

class KBCClient {
    constructor(rootElement) {
        this.client = Client({ game: KBC });
        this.client.start();
        this.rootElement = rootElement;

        this.client.subscribe(state => this.update(state));
        this.createBoardLayout();
    }

    createBoardLayout() {
        const rows = [];
        for (let row = 0; row < 20; row++) {
            const cells = [];
            for (let col = 0; col < 20; col++) {
                const id = `${row}-${col}`;
                cells.push(`<td class="cell" data-id="${id}"></td>`);
            }
            rows.push(`<tr>${cells.join('')}</tr>`);
        }
        this.rootElement.innerHTML = `<table>${rows.join('')}</table>`;
        this.update(this.client.getState());
    }

    update(state) {
        const board = new Board(state.G);
        const cells = this.rootElement.querySelectorAll(".cell");
        cells.forEach(cell => {
            const coords = cell.dataset.id.split("-");
            const r = coords[0];
            const c = coords[1];
            cell.textContent = board.terrainAt(c, r);
        })
    }
}

const appElement = document.getElementById('app');
const app = new KBCClient(appElement);

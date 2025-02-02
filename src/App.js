import { Client } from 'boardgame.io/client';
import { KBC } from './Game';

class KBCClient {
    constructor() {
        this.client = Client({ game: KBC });
        this.client.start();
    }
}

const app = new KBCClient();

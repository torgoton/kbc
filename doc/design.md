# KBC Design

This app is meant to be an implementation of the board game Kingdom Builder.

I began it for a few reasons:
* Because no current implementation includes any expansions
* To build a project by myself
* To learn current technologies and best practices in the current versions of Ruby and Rails
* To learn JavaScript more thoroughly

# Screens
## Login
* MVP
    * sign up request button/link
    * handle field
    * password field
    * login button

## Dashboard
* MVP
    * games in progress
    * start a new game

* Final
    * Banned handles
    * Friend list
    * Find friends

## (New) game settings
* POC
    * NONE

        The game will exactly mimic the "First Game" setup from the rules book.
        The board sections are Tavern, Paddock, Oasis, and Farm.
        The goal cards are Fishermen, Knights, and Merchants.

* MVP
    * First Game / Random
    * 2 players only

* Final
    * Number of players
    * Reserve spots for individuals
    * Allow anyone to join
    * All expansions

## The game
* MVP
    * Display board - assume experienced players
    * Display goals - assume experienced players
    * Remaining deck
    * Number of remaining pieces
    * Final score
    * Continual score?
* Final
    * Board has detailed info and example
    * Goals have detailed info and example
    * Decrees

## Boards
* POC
    * Tavern (build)
    * Paddock (move)
    * Oasis (build)
    * Farm (build)
* MVP
    * Oracle (build)
    * Tower (build)
    * Harbod (move)
    * Barn (move)
* Final
    * Nomads
        * Quarry (add)
        * Caravan (move)
        * Village (build)
        * Garden (build)
        * Nomad tiles
            * Donation (build)
            * Resettlement (move)
            * Outpost (alter)
            * Sword (remove)
            * Treasure (score)
    * Crossroads
        * Lighthouse (nomad Ship)
        * Forester's Lodge (build)
        * Barracks (nomad Warrior)
        * Crossroads (handsize)
        * City Hall (build)
        * Fort (build)
        * Monastery (build)
        * Wagon (nomad Wagon)
    * Marshlands
        * Temple (remove)
        * Refuge (move)
        * Canoe (build)
        * Fountain (build)
    * Harvest
        * Bazaar (repeat)
        * Water Mill (build)
        * Mountain Station (build)
        * Scout Cabin (place)
        * Cathedral (build)
        * Watchtower (build)
        * University (build)
        * Palisade (move)
        * Farm action (build)
    * Island
        * Rope Bridge (move)
        * Tree House (move)

## Goals
* POC
    * Fishermen
    * Knights
    * Merchants
* MVP
    * Discoverers
    * Hermits
    * Citizens
    * Miners
    * Farmers
* Final
    * Nomads
        * Families
        * Shepherds
        * Ambassadors
    * Crossroads Task cards
        * Home Country
        * Fortress
        * Road
        * Place of Refuge
        * Advance
        * Compass Points
    * Marshlands
        * Geologists
        * Messengers
        * Noblewomen
        * Vassals
        * Captains
        * Scouts
        * Palaces
    * Harvest
        * Rangers
        * Mayors
        * Chainers
        * Travellers
        * Homesteaders
        * Rovers
    * Capitols

## Terrain cards
* POC
    * 25 terrain cards in base game
* MVP
    * Nothing new
* Final
    * Marshlands
        * Swamp

## Pieces and tokens
* POC
    * Player settlement pieces
* MVP
    * Nothing new
* Final
    * Nomads
        * Stone Walls
    * Crossroads
        * Warriors
        * Wagons
        * Ships
        * City Halls
    * Harvest
        * #5 tiles
        * #1 tiles
        * Scouts
    * Caves
    * Capitols
    * Ferry tile
    * Volcano tile

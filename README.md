# Gameboy/Game Boy Color for Analogue Pocket
Ported from the original core developed at https://github.com/MiSTer-devel/Gameboy_MiSTer

Please report any issues encountered to this repo. Issues will be upstreamed as necessary.

## Installation
To install the core, copy the `Assets`, `Cores`, and `Platform` folders over to the root of your SD card. Please note that Finder on macOS automatically _replaces_ folders, rather than merging them like Windows does, so you have to manually merge the folders.
Place GBC and GB bios in `/Assets/gbc/common` named "gbc_bios.bin" and "gb_bios.bin" respectively.

## Usage
ROMs should be placed in `/Assets/gbc/common`. Both headered and unheadered ROMs are now supported.

## Features

### Supported
Real-Time Clock
Fastforward
Original Gameboy display modes

### In Progress
Super Gameboy Support
Custom Borders
SaveStates
Custom Palette Loading

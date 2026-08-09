# Gameboy/Game Boy Color for Analogue Pocket

Ported from the original core developed at https://github.com/MiSTer-devel/Gameboy_MiSTer

Please report any issues encountered to this repo. Issues will be upstreamed as necessary.

## Installation

To install the core, copy the `Assets`, `Cores`, and `Platform` folders over to the root of your SD card. Please note that Finder on macOS automatically *replaces* folders, rather than merging them like Windows does, so you have to manually merge the folders.

Place the GBC BIOS in `/Assets/gbc/common` named `gbc_bios.bin`, the GB BIOS in `/Assets/gb/common` named `gb_bios.bin`, and the SGB BIOS in `/Assets/gb/common` named `sgb_boot.bin`.

## Build from Source

The GB and GBC cores are built from the same Quartus project. Before compiling, the source must be configured for the desired target.

### 1. Install the Correct Quartus Version

Check `src/ap_core.qsf` for the `LAST_QUARTUS_VERSION` assignment:

```text
set_global_assignment -name LAST_QUARTUS_VERSION "..."
```

Install the corresponding version of Intel Quartus Prime. Cyclone V device support must also be installed, as the Analogue Pocket core FPGA is a Cyclone V device.

Verify the Quartus command-line tools are available:

```shell
quartus_sh --version
```

If `quartus_sh` is not in your `PATH`, run it directly from the Quartus installation directory or add the Quartus `bin64` directory to your `PATH`.

### 2. Select the GB or GBC Build

Open:

```text
src/core/core_top.sv
```

Near the top of the file is the `isgbc` define:

```systemverilog
`define isgbc 0
```

Set this value according to the core you want to build:

```text
0 = Game Boy / Super Game Boy
1 = Game Boy Color
```

For the Game Boy core:

```systemverilog
`define isgbc 0
```

For the Game Boy Color core:

```systemverilog
`define isgbc 1
```

This setting is important. Building with the wrong value will produce a valid FPGA bitstream for the wrong core configuration.

### 3. Clean Previous Quartus Build Files (if they exist)

When switching versions, branches, tags, or GB/GBC configurations, it is recommended to remove previous Quartus build output before compiling.

`git clean` is the easiest way to clean up the repo for the next build. Make sure you save off the previously built `.rbf_r` before running.

```bash
git clean -fX -d
```

### 4. Compile the Core

From the `src` directory, run:

```shell
quartus_sh --flow compile ap_core
```

After a successful build, Quartus will generate:

```text
src/output_files/ap_core.rbf
```

### 5. Convert the RBF for openFPGA

Analogue Pocket openFPGA cores use an `.rbf_r` bitstream. The bits within each byte of the Quartus-generated `.rbf` must be reversed.

One way to reverse the bits is to use Analogue's `pf-dev-tools` Python package:

It can be installed with the following command:

```shell
pip install pf-dev-tools
```

Then convert the generated bitstream using:

```shell
pf reverse output_files/ap_core.rbf output_files/gb.rbf_r
```

for a Game Boy build, or:

```shell
pf reverse output_files/ap_core.rbf output_files/gbc.rbf_r
```

for a Game Boy Color build.

### 6. Install the Compiled Bitstream

For a Game Boy build, copy:

```text
output_files/gb.rbf_r
```

to:

```text
/Cores/budude2.GB/gb.rbf_r
```

on the Analogue Pocket SD card.

For a Game Boy Color build, copy:

```text
output_files/gbc.rbf_r
```

to:

```text
/Cores/budude2.GBC/gbc.rbf_r
```

## Usage

ROMs should be placed in `/Assets/gbc/common`, and `/Assets/gb/common`.

## Features

### Supported

* Real-Time Clock
* Fastforward
* Original Gameboy display modes
* Super Gameboy Emulation
* Custom Borders (SGB)
* Custom Palettes (SGB)
* Enhance GBA features
* Save States and Sleep
* External Cartridges

### In Progress

¯\*(ツ)*/¯

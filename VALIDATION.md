# Validation record

Date: **2026-10-24**. Platform: Windows, PowerShell.

## Compilation

**Questa Intel Starter FPGA Edition 2021.2**, VHDL-2008:

| Project | RTL files | Testbench files | Result |
| --- | ---: | ---: | --- |
| MCU | 31 | 5 | All compile; 0 errors, 3 compiler warnings |
| Pipeline | 17 | 1 | All compile; 0 errors, 3 compiler warnings |

Compilation uses the vendor's installed `altera_mf` library. The pipeline simulation configuration is generated in the build directory and its sources compile with the PLL bypass selected. Committed hardware source packages retain FPGA mode.

**Quartus Prime Lite 21.1.0 Build 842**, Cyclone V `5CSXFC6D6F31C6`:

Both independent projects pass Analysis & Synthesis with zero errors. This exercises elaboration of the selected top-levels, vendor RAM/PLL primitives and repository-local memory initialization files; it is more than a syntax-only check.

## Warnings and limits

- Questa emits three `vcom-1074` warnings per project for non-locally static `OTHERS` aggregate choices in the original execute stage. Compilation succeeds. These source constructs are retained to preserve the submitted RTL.
- Quartus reports unused signals in the recovered design. The MCU also reports unused switch bits 8/9 and LED bits 8/9 tied low; its implemented GPIO datapath is eight bits wide.
- Both projects declare 2,048-word memories. Recovered firmware initializes fewer words (MCU: 304 instruction / 1,024 data; pipeline RT5: 45 instruction / 1,024 data). Quartus issues critical warning 127005 and explicitly zero-fills the rest. Images are preserved rather than silently regenerated.
- The pipeline's debug ports are assigned virtual pins for synthesis. That project is not a board pinout.
- `vsim` could not start because no valid simulator license was available in this environment. **No new simulation pass, memory-result comparison or functional-correctness claim is made.** The supplied simulation runners require an enabled simulator license and check completion/pass markers.
- Fitting, place-and-route, timing closure, programming and physical-board operation were not repeated during recovery. Historical submission bitstreams and reports are not used as proof that a fresh build passes those stages.

## Reproduction

Run the four compilation/synthesis commands in the root README after cloning. No original `C:/ModelSim/LABS` directory or pre-existing Quartus/ModelSim database is required. Only an installed toolchain and its standard vendor libraries are needed for these checks.

`SOURCE_MANIFEST.json` preserves hashes for each recovered source, testbench, firmware image, timing constraint and original README. The limited path-only edits are identified explicitly. New build/documentation files are ordinary repository files rather than recovered artifacts.

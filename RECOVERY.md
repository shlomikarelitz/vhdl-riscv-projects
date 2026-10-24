# Source selection

Recovery and packaging date: **2026-10-24**.

## Final-project MCU

The final-submission directory contains `DOC`, `DUT`, `QUARTUS`, `SIM` and `TB`, plus a saved submission ZIP. It supplies 31 RTL files and one MCU testbench. All **32 VHDL files match the corresponding files in that ZIP byte for byte**.

The same 31 RTL files also occur unchanged in the separate `LABBALAGAN` hand-in copy, its ZIP, the flat final-project `DUT`, and the logically organized `DUT BY MODULES` directory. The last saved root `FINAL.qsf` (2026-08-31) explicitly selects `LABBALAGAN/DUT`, confirming which source set the hardware project used. Older backup and nested experimental variants differ and were not selected.

The original final-submission `QUARTUS` folder contains a bitstream, timing constraints and SignalTap data but lacks the QPF/QSF needed to rebuild. Portable project files were therefore created using the verified top-level, device and latest root project's board pins. The original bitstream and generated databases are omitted; users rebuild from source.

The firmware images referenced by the submitted testbench were recovered from the final project's interrupt-based test4 directory. Both HEX images are byte-identical to the final root hardware images. Four existing unit testbenches were added from the final project's regression folder.

## Lab 5 pipeline

The directory explicitly named **"תיקייה סופית להגשה"** contains separate single-cycle and pipeline implementations. Its submission ZIP contains 30 VHDL files, and all **30 match the corresponding final-submission files byte for byte**. This repository selects only the pipeline's 17 RTL files and one testbench.

The later working copy has the same pipeline logic. Its one changed RTL file, `MEM_STAGE_pipeline.vhd`, changes only an unused default DTCM filename; the top-level already passes its selected image explicitly. The submitted top-level selects the RT5 image pair, which is included here.

## Packaging changes

- MCU RTL: all 31 files retained byte for byte.
- Pipeline RTL: four files have only their memory-image filename defaults made relative. No datapath or control logic was edited.
- MCU submitted testbench: its two memory-image paths were made relative. Pipeline testbench and four additional MCU tests are unchanged.
- New compilation order lists, PowerShell runners, fail-fast simulator scripts, portable Quartus settings and documentation.
- Source notices and original README files retained. Reports with personal identifiers, alternate projects, archives, logs, tool databases and large generated artifacts excluded.

`SOURCE_MANIFEST.json` records the original and packaged SHA-256 for each recovered file. Repository attributes disable automatic line-ending conversion so these hashes remain stable after cloning. Original local folders were not modified.

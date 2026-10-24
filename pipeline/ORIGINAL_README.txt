Lab 5: RISC-V RV32IM Implementation

This repository contains our files for Lab 5. We implemented a RISC-V processor in two versions:
- A Single-Cycle datapath
- A 5-stage Pipelined datapath

We also added a 16-bit hardware multiplier to support the RV32M extension.

Folders:
- DUT/ : Contains all the VHDL source files. There are separate subfolders for the single cycle and the pipeline versions.
- SIM/ : Scripts to run the simulations in ModelSim.
- TB/ : Our testbenches.
- Benchmark/ : The compiled test programs (.hex files) that we used to test the processor.

How to run:
In the file cond_compilation_package.vhd, there is a constant called G_MODELSIM.
- To simulate in ModelSim, set G_MODELSIM := 1. This bypasses the PLL so the testbench works.
- To compile in Quartus and run on the FPGA, set G_MODELSIM := 0.

For simulation, we ran sim_pipeline.do in ModelSim and checked the CLKCNT, STCNT, and FHCNT counters to calculate the IPC.
For the FPGA part, we programmed the DE10-Standard board and used SignalTap to monitor the actual hardware signals.

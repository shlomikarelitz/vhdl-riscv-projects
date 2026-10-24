# RISC-V MCU & Pipelined Processor in VHDL

Two university projects from the **Advanced CPU Architecture and Hardware Accelerators** laboratory at Ben-Gurion University, developed for Intel Cyclone V and the DE10-Standard board.

**Project partners:** [Shlomi Karelitz](https://github.com/shlomikarelitz) and [Adiel Mamedov (עדיאל ממדוב)](https://github.com/AdielMamedov).

| Project | Architecture | Main features |
| --- | --- | --- |
| [Final-project MCU](mcu/) | RV32I-based single-cycle core with a multicycle divider | Harvard instruction/data memories, memory-mapped GPIO, interrupts, timer, capture/PWM and hardware arithmetic |
| [Lab 5 pipelined processor](pipeline/) | Five stages: IF, ID, EX, MEM, WB | Forwarding, stalls, branch redirection, pipeline registers, hardware multiplication and performance counters |

Each project has its own RTL, testbenches, memory images and build scripts. They use separate compilation libraries because some packages and entities have the same names but different implementations.

## Quick start

Install **Quartus Prime Lite 21.1** with Cyclone V support and **Questa Intel FPGA Edition 2021.2** (or a compatible ModelSim/Questa installation containing `altera_mf`). Simulation execution also requires a valid simulator license. Vendor tools and libraries are not included.

```powershell
git clone https://github.com/shlomikarelitz/vhdl-riscv-projects.git
cd vhdl-riscv-projects

# Set these to the directories containing your installed executables.
$questaBin = 'C:\intelFPGA_lite\questa_fse\win64'
$quartusBin = 'C:\intelFPGA_lite\quartus\bin64'

# Compile all RTL and testbenches, independently for each project.
.\mcu\simulate.ps1 -QuestaBin $questaBin -CompileOnly
.\pipeline\simulate.ps1 -QuestaBin $questaBin -CompileOnly

# Quartus Analysis & Synthesis.
.\mcu\synthesize.ps1 -QuartusBin $quartusBin
.\pipeline\synthesize.ps1 -QuartusBin $quartusBin

# Run the supplied simulations when a simulator license is available.
.\mcu\simulate.ps1 -QuestaBin $questaBin
.\pipeline\simulate.ps1 -QuestaBin $questaBin
```

The scripts locate files relative to their own project directory. Run them from any working directory. Generated libraries, simulator transcripts and Quartus databases are ignored by Git. PowerShell must permit running local scripts under your usual execution policy.

## What was verified

Both projects' RTL and testbenches compile in Questa `vcom` with **zero errors**, with three compiler warnings per project in the original execute-stage aggregates. Both Quartus Analysis & Synthesis builds complete with **zero errors**. See [VALIDATION.md](VALIDATION.md) for tool versions, warnings and limits.

Simulation execution could not be repeated during recovery because this machine's Questa simulator license was unavailable. A successful compilation is not a claim of functional correctness, timing closure or a new physical-board test.

## Source selection and credits

The MCU sources come from the final submission bundle and match the source set referenced by the last saved Quartus project. The pipeline sources come from Lab 5's final-submission directory; its single-cycle alternative is not included here. See [RECOVERY.md](RECOVERY.md) and [SOURCE_MANIFEST.json](SOURCE_MANIFEST.json) for the selection evidence and precise portability edits.

These are lab-team implementations built on course-provided RISC-V materials. Existing Hananya Ribo/BGU and Intel/Altera notices are retained. [NOTICE.md](NOTICE.md) describes the included baseline and vendor-generated files.

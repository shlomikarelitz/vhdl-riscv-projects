# RV32IM MCU Project - Final Lab

## Project Overview
This project is a complete implementation of a RISC-V 32-bit Microcontroller (RV32IM) with various peripherals, designed for the Intel Cyclone V (DE10-Standard) FPGA.

### Architecture (Single-Cycle)
- **RV32I Core**: Single-cycle RISC-V processor.
- **M Extension (DIVIDER)**: Hardware accelerator for multiplication and division.
- **Interrupt Controller**: Handles hardware interrupts from peripherals.
- **Basic Timer**: Programmable timer with Capture and Compare/PWM capabilities.
- **GPIO**: Memory-mapped interfaces for LEDs, Hex displays, Switches, and Pushbuttons.

## Directory Structure (DUT BY MODULES)
To facilitate learning and understanding, the VHDL source files are organized logically:
- **CORE/**: The CPU core, memory, and data routing.
- **PERIPHERALS/**: Timer, LEDs, Switches, Displays.
- **INTERRUPTS/**: Interrupt controllers and management.
- **DIVIDER/**: The hardware M-extension (Multiplier/Divider).
- **SYSTEM/**: Clock/Reset manager, PLL, and Top-Level entities.
- **COMMON/**: Constants and packages.

*Note: The project does not include pipelining as per the latest requirements.*


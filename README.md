UART Core
=========

Overview
---------
This repository contains a synthesizable UART (Universal Asynchronous Receiver/Transmitter) core intended for use in FPGA/ASIC designs. The implementation, and top-level wrapper are located under ./src/design. Testbenches are located in ./src/testbench.

Key features
-------------
- Configurable baud rate generator
- Transmit (TX) and receive (RX) FIFOs / buffers (implementation-dependent)
- Parameterizable Clock Frequency, Data Bits and Baud Rate
- Clean synchronous design suitable for synthesis

Repository layout
-----------------
- src/  - RTL sources, wrappers and testbenches for the UART core
- sim/  - Simulation output files (.vvp and .vcd)
- docs/ - Additional documentation and diagrams

Top-level interface
--------------------------
The UART Transceiver core (src/design/uart.v) provides the following ports:

- sys_clk           : system clock
- sys_rst_l         : active-low reset
- xmit_H            : pulse/strobe to send a byte
- xmit_dataH[7:0]   : data to transmit
- uart_REC_dataH    : serial input
- uart_XMIT_dataH   : serial output
- xmit_active       : transmitter active indicator
- xmit_doneH        : transmission done indicator
- rec_done          : pulse/strobe indicating received byte available
- rec_busy          : pulse/strobe indicating received byte available
- rec_dataH[7:0]    : received data byte

Parameters & configuration
--------------------------
Parameters such as DATA_BITS, STOP_BITS, PARITY and default BAUD_DIV (or BAUD_RATE) are defined in the RTL. Check src/design/inc.vh files to see available generics/parameters and default values.

```
`define XTAL_CLK 50_000_000         // Default Clock Frequency
`define BAUD 115_200                // Default Baud Rate

`define WORD_LEN 8                  // Default Word Length (8 bits)
`define CW $clog2(`WORD_LEN)
```

Building & simulation
---------------------
Use your preferred toolchain (iverilog/verilator/Xilinx Vivado/Intel Quartus) to build and simulate. Typical steps:

1. Add src/design/*.v to your simulator project.
2. Run the included testbench.
3. Observe tx and rx handshake signals and verify data integrity.

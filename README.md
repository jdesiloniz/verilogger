# Verilogger

Verilogger is a simple logger module designed in Verilog. You can use Verilogger in your own designs to log different information to an external device through different protocols (i.e.: UART, SPI...).

## Design

Verilogger comes with a FIFO memory that allows keeping up with logged messages if the external device is slower than the processes producing the information to be sent. Depending on the speed you plan to generate messages, this FIFO will probably not be enough to store all data, so please take into account the amount of memory needed to avoid this (or switch to using a faster external device).

The main design goal with Verilogger is to keep dependencies with vendor-specific devices as much as possible. That's why the module has connections for memory lines (that can be easily wired to vendor-specific block RAM modules), and also allows to be used with modules for different external devices (i.e.: UART, SPI...).

## How to use

In order to use Verilogger you need to:

* Instantiate block RAM and connect it properly with the `logger` module (signals `mem_addr_w`, `mem_addr_r`, `mem_rw`, `mem_data_in`, `mem_data_out`).
* Instantiate external device to send logs (it should use a *busy* signal, *stb* signal for activation and *data* signal for each byte to be sent, those should be mapped to `logger`'s `ext_stb`, `ext_data`, `ext_busy`).
* Set the configuration parameters to the appropiate values (address and data widths for FIFO memory, FIFO size in words of the intended data width, number of characters per message, and the size of the number of characters - `log2(chars)`).
* The `logger` module should be instantiated correctly. Your processes can set the `text` signal to set the message, and the `stb` signal to ask the logger to store it and (when possible) log it to the external device. Please take into account the `busy` and `full` signals to avoid losing messages on the way.

Please refer to the provided example `logger_example_lattice` (intended for the ICE40 series from Lattice) to see how it's used.

## External devices

An implementation for UART transmission is currently available. 

## TODOs

* Better test bench (currently a simple iverilog test bench is provided).
* Test logger with other vendors (i.e.: Xilinx Spartan-6 devices).
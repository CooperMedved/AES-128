## =========================================================
## Clock: 100 MHz oscillator (Nexys A7)
## =========================================================
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }];
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports { CLK100MHZ }];

## =========================================================
## USB-RS232 (onboard USB-UART via FTDI)
## Nexys A7 Master XDC:
##   C4 = UART_TXD_IN  (PC -> FPGA, so this is our RX)
##   D4 = UART_RXD_OUT (FPGA -> PC, so this is our TX)
## =========================================================
set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { UART_RX }];  # FTDI TX -> FPGA RX
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { UART_TX }];  # FPGA TX -> FTDI RX

## (Optional) CTS / RTS if you ever use them:
# set_property -dict { PACKAGE_PIN D3    IOSTANDARD LVCMOS33 } [get_ports { UART_CTS }];
# set_property -dict { PACKAGE_PIN E5    IOSTANDARD LVCMOS33 } [get_ports { UART_RTS }];

## =========================================================
## Buttons
## Master XDC: N17 is BTNC (center push button)
## =========================================================
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { BTNC }];     # Center button

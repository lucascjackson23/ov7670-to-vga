## ov7670_to_vga constraints -- Basys 3
## Port names match ov7670_to_vga.sv

## System clock (100MHz onboard oscillator)
## Declared explicitly here rather than relying on the Clocking Wizard's
## auto-generated constraint: the clk port fans out to both wizards and
## directly to the submodules, so the IP's own constraint does not reliably
## apply to the whole net.
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

## Reset (center pushbutton, btnC)
set_property PACKAGE_PIN U18 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

## init done indicator (LD0)
set_property PACKAGE_PIN U16 [get_ports ov7670_init_done]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_init_done]

## transform select (SW0-SW2)
set_property PACKAGE_PIN V17 [get_ports {transform_sel[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {transform_sel[0]}]
set_property PACKAGE_PIN V16 [get_ports {transform_sel[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {transform_sel[1]}]
set_property PACKAGE_PIN W16 [get_ports {transform_sel[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {transform_sel[2]}]

## OV7670 outputs (FPGA -> camera), PMOD JC
set_property PACKAGE_PIN M18 [get_ports ov7670_xclk]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_xclk]
set_property PACKAGE_PIN R18 [get_ports ov7670_sio_c]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_sio_c]
set_property PACKAGE_PIN P18 [get_ports ov7670_sio_d]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_sio_d]
set_property PACKAGE_PIN L17 [get_ports ov7670_reset_n]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_reset_n]
set_property PACKAGE_PIN K17 [get_ports ov7670_pwdn]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_pwdn]

## SCCB data line is open-drain -- needs a pull-up.
## Harmless if the breakout board already has external pull-ups fitted.
set_property PULLUP true [get_ports ov7670_sio_d]

## OV7670 inputs (camera -> FPGA), PMOD JC
set_property PACKAGE_PIN N17 [get_ports ov7670_href]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_href]
set_property PACKAGE_PIN P17 [get_ports ov7670_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_vsync]
set_property PACKAGE_PIN M19 [get_ports ov7670_pclk]
set_property IOSTANDARD LVCMOS33 [get_ports ov7670_pclk]

## Pixel data bus D0-D7, PMOD JB
set_property PACKAGE_PIN A14 [get_ports {ov7670_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[0]}]
set_property PACKAGE_PIN A15 [get_ports {ov7670_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[1]}]
set_property PACKAGE_PIN A16 [get_ports {ov7670_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[2]}]
set_property PACKAGE_PIN A17 [get_ports {ov7670_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[3]}]
set_property PACKAGE_PIN B15 [get_ports {ov7670_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[4]}]
set_property PACKAGE_PIN C15 [get_ports {ov7670_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[5]}]
set_property PACKAGE_PIN B16 [get_ports {ov7670_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[6]}]
set_property PACKAGE_PIN C16 [get_ports {ov7670_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ov7670_data[7]}]

## VGA outputs (Basys 3 onboard VGA connector)
set_property PACKAGE_PIN G19 [get_ports {vga_r[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN H19 [get_ports {vga_r[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN J19 [get_ports {vga_r[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN N19 [get_ports {vga_r[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[3]}]

set_property PACKAGE_PIN J17 [get_ports {vga_g[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN H17 [get_ports {vga_g[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN G17 [get_ports {vga_g[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN D17 [get_ports {vga_g[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[3]}]

set_property PACKAGE_PIN N18 [get_ports {vga_b[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN L18 [get_ports {vga_b[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN K18 [get_ports {vga_b[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN J18 [get_ports {vga_b[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[3]}]

set_property PACKAGE_PIN P19 [get_ports vga_hsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hsync]
set_property PACKAGE_PIN R19 [get_ports vga_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vsync]

## Timing
##
## PCLK is NOT used as a clock -- ov7670_capture oversamples it with the
## system clock and synchronises it like any other async input. So there is
## no create_clock and no CLOCK_DEDICATED_ROUTE override needed.
set_false_path -from [get_ports ov7670_pclk]
set_false_path -from [get_ports ov7670_href]
set_false_path -from [get_ports ov7670_vsync]
set_false_path -from [get_ports {ov7670_data[*]}]

## The system clock and the VGA pixel clock both come from the same 100MHz
## source but drive unrelated logic. The frame buffer crosses between them
## with no handshake (single buffered, tearing accepted), so do not time
## paths between the two domains.
set_clock_groups -asynchronous \
    -group [get_clocks sys_clk] \
    -group [get_clocks -of_objects [get_pins clk_wiz_1_inst/clk_out1]]

## SCCB / camera control outputs -- slow, non-timing-critical
set_false_path -to [get_ports ov7670_sio_c]
set_false_path -to [get_ports ov7670_sio_d]
set_false_path -to [get_ports ov7670_reset_n]
set_false_path -to [get_ports ov7670_pwdn]
set_false_path -to [get_ports ov7670_xclk]

## Status LED
set_false_path -to [get_ports ov7670_init_done]

## Async pushbutton reset
set_false_path -from [get_ports rst]

## Async slide switches -- synchronised in the design
set_false_path -from [get_ports {transform_sel[*]}]

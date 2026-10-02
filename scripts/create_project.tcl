# Recreates the Vivado project in build/ from the sources in this repo.
# Usage (from the repo root): vivado -mode batch -source scripts/create_project.tcl

set root [file normalize [file join [file dirname [info script]] ..]]

create_project ov7670_to_vga [file join $root build] -part xc7a35ticpg236-1L -force

add_files [glob [file join $root rtl *.sv]]
add_files [file join $root rtl ov7670_init.mem]
add_files -fileset constrs_1 [file join $root constraints basys3.xdc]
add_files [glob [file join $root ip * *.xci]]
upgrade_ip [get_ips]

set_property top ov7670_to_vga [current_fileset]

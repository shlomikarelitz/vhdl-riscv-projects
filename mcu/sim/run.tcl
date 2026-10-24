onerror {quit -code 1 -force}
# Return from std.env.finish/stop to the DO file. The runner rejects assertion
# failures in the transcript and requires every independent test's pass marker.
onbreak {resume}
set project [file normalize [file join [file dirname [info script]] ..]]
# Memory paths are relative to the project, independent of caller's cwd.
cd $project
# std.env.finish returns control to Tcl, so every expected marker is checked by the runner.
foreach unit {tb_divider_targeted tb_interrupt_controller tb_basic_timer tb_basic_timer_phase8b} {
    vsim -t 1ps -onfinish stop -L altera_mf work.$unit
    # A finite deadline also catches a test that never reaches std.env.finish.
    run 1 ms
    puts "UNIT FINISHED: $unit"
    quit -sim
}
vsim -t 1ps -onfinish stop -L altera_mf work.tb_simple_mcu
run 100 us
puts "MCU SMOKE PASS: 100 us, submitted testbench and interrupt_demo images"
quit -sim
quit -code 0 -force

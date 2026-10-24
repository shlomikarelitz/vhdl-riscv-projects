onerror {quit -code 1 -force}
onbreak {resume}
set project [file normalize [file join [file dirname [info script]] ..]]
# Memory paths are relative to the project, independent of caller's cwd.
cd $project
vsim -t 1ps -voptargs=+acc -L altera_mf work.tb_pipeline
run 1 ms
if {![string equal -nocase [examine /tb_pipeline/sim_done] "TRUE"]} {
    error "Pipeline benchmark did not reach its completion instruction"
}
puts "PIPELINE SMOKE PASS: RT5 reached the submitted testbench completion instruction"
quit -sim
quit -code 0 -force

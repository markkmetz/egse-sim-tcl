set here [file dirname [file normalize [info script]]]
set root [file dirname $here]

set suites [list \
    [file join $here test_dispatch_listeners.tcl] \
    [file join $here test_mib_loader.tcl] \
    [file join $here test_protocol_decode.tcl] \
    [file join $here test_socket_flow.tcl] \
    [file join $here test_transport_combined.tcl] \
    [file join $here test_e2e_packet_matrix.tcl] \
    [file join $here test_transport_udp_optional.tcl]]

set failed 0
foreach s $suites {
    puts "Running $s"
    if {[catch {
        exec tclsh $s
    } out]} {
        puts $out
        incr failed
    } else {
        puts $out
        if {[regexp {Failed\s+([1-9][0-9]*)} $out]} {
            incr failed
        }
    }
}

if {$failed > 0} {
    error "$failed test suite(s) failed"
}

puts "All suites passed"

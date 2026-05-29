package require tcltest
namespace import ::tcltest::*

set here [file dirname [file normalize [info script]]]
set root [file dirname $here]

source [file join $root lib egse transport.tcl]

if {[catch {package require udp}]} {
    puts "udp package not available: skipping UDP transport test"
} else {
    test udp-transport-001 {udp mode can start and stop} -body {
        set cfg [dict create \
            transport_mode separate \
            tc_transport udp \
            tm_transport udp \
            tc_host 127.0.0.1 \
            tc_port 5800 \
            tm_host 127.0.0.1 \
            tm_port 5801]

        set seen 0
        proc onUdpTc {transport endpoint raw} {
            set ::seen 1
        }

        egse::transport::start $cfg onUdpTc
        egse::transport::stop
        set ::seen
    } -result 0
}

cleanupTests

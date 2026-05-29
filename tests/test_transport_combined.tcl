package require tcltest
namespace import ::tcltest::*

set here [file dirname [file normalize [info script]]]
set root [file dirname $here]

source [file join $root lib egse mib_loader.tcl]
source [file join $root lib egse protocol.tcl]
source [file join $root lib egse dispatcher.tcl]
source [file join $root lib egse egse_registry.tcl]
source [file join $root lib egse transport.tcl]

set cfg [dict create \
    transport_mode combined \
    tc_transport tcp \
    tm_transport tcp \
    tc_host 127.0.0.1 \
    tc_port 5700 \
    tm_host 127.0.0.1 \
    tm_port 5700]

set mibIndex [egse::mib::loadMibSet [file join $root examples mibs] generic]
egse::registry::activate $root [dict create egse_type generic]

set ::rx ""
set ::done 0

proc onTcPacketCombinedTest {cfg mibIndex transport endpoint rawPacket} {
    set decoded [egse::protocol::decodeTcPacket $rawPacket $mibIndex]
    set actionResult [egse::dispatch::handleTc $decoded]
    set tm [egse::protocol::buildTmFromMib \
        $decoded \
        $mibIndex \
        [dict get $actionResult tm_service_type] \
        [dict get $actionResult tm_subservice] \
        [dict get $actionResult tm_param_values]]
    egse::transport::sendTm $cfg $tm
}

proc onCombinedReadable {sock} {
    append ::rx [read $sock]
    if {[string length $::rx] >= 12} {
        set ::done 1
    }
}

test combined-transport-001 {single combined socket handles TC in and TM out} -body {
    set ::rx ""
    set ::done 0

    egse::transport::start $cfg [list onTcPacketCombinedTest $cfg $mibIndex]

    set sock [socket 127.0.0.1 5700]
    fconfigure $sock -blocking 0 -translation binary -buffering none
    fileevent $sock readable [list onCombinedReadable $sock]

    set payload [binary format cccca* 17 17 1 1 [binary format cc 0 5]]
    set tc [egse::protocol::encodeSpacePacket \
        packet_type 1 \
        apid 100 \
        sequence_count 44 \
        payload $payload]
    puts -nonewline $sock $tc
    flush $sock

    after 1500 { if {!$::done} { set ::done timeout } }
    vwait ::done

    close $sock
    egse::transport::stop

    if {$::done eq "timeout"} {
        error "Timed out waiting for combined TM response"
    }

    set decoded [egse::protocol::decodeSpacePacket $::rx]
    binary scan [dict get $decoded payload] cccc _ st sst _
    list [dict get $decoded packet_type] $st $sst
} -result {0 17 2}

cleanupTests

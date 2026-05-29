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
    tc_transport tcp \
    tm_transport tcp \
    tc_host 127.0.0.1 \
    tc_port 5600 \
    tm_host 127.0.0.1 \
    tm_port 5601]

set mibIndex [egse::mib::loadMibSet [file join $root examples mibs] generic]

egse::registry::activate $root [dict create egse_type generic]

set ::tmBytes ""
set ::done 0

proc onTcPacketForTest {cfg mibIndex transport endpoint rawPacket} {
    set decoded [egse::protocol::decodeTcPacket $rawPacket $mibIndex]
    set actionResult [egse::dispatch::handleTc $decoded]
    set tmValues [dict create]
    if {[dict exists $actionResult tm_param_values]} {
        set tmValues [dict get $actionResult tm_param_values]
    }
    set tmPacket [egse::protocol::buildTmFromMib \
        $decoded \
        $mibIndex \
        [dict get $actionResult tm_service_type] \
        [dict get $actionResult tm_subservice] \
        $tmValues]
    egse::transport::sendTm $cfg $tmPacket
}

proc onTmReadableForTest {sock} {
    append ::tmBytes [read $sock]
    if {[string length $::tmBytes] >= 11} {
        set ::done 1
    }
}

test socket-flow-001 {TC on TC socket generates TM on TM socket} -body {
    set ::tmBytes ""
    set ::done 0

    egse::transport::start $cfg [list onTcPacketForTest $cfg $mibIndex]

    set tmSock [socket 127.0.0.1 5601]
    fconfigure $tmSock -blocking 0 -translation binary -buffering none
    fileevent $tmSock readable [list onTmReadableForTest $tmSock]

    set tcSock [socket 127.0.0.1 5600]
    fconfigure $tcSock -blocking 0 -translation binary -buffering none

    set params [binary format cc 18 52]
    set payload [binary format cccca* 17 17 1 1 $params]
    set tcPacket [egse::protocol::encodeSpacePacket \
        packet_type 1 \
        apid 100 \
        sequence_count 33 \
        payload $payload]

    puts -nonewline $tcSock $tcPacket
    flush $tcSock

    after 1500 { if {!$::done} { set ::done timeout } }
    vwait ::done

    close $tcSock
    close $tmSock
    egse::transport::stop

    if {$::done eq "timeout"} {
        error "Timed out waiting for TM response"
    }

    set tmDecoded [egse::protocol::decodeSpacePacket $::tmBytes]
    binary scan [dict get $tmDecoded payload] cccc tmPus0 tmSt tmSst tmSrc
    list $tmSt $tmSst [binary encode hex [string range [dict get $tmDecoded payload] 4 end]]
} -result {17 2 1234}

cleanupTests

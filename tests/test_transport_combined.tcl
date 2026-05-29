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

# Build an in-memory test MIB index matching the APID/service/sub values used below.
proc _buildTestMibIndex {} {
    set pingCmd [dict create \
        command_name PING_RF  apid 100  service_type 17  subservice 1 \
        description "RF ping"  action rf_ping]
    set psuCmd [dict create \
        command_name PSU_SET_VOLTAGE  apid 100  service_type 3  subservice 1 \
        description "PSU set voltage"  action psu_set_voltage]
    set pingParam [dict create param_name echo_data  offset 0  length 2  type U16]
    set psuParam  [dict create param_name voltage_mv offset 0  length 2  type U16]
    set pingTm [dict create tm_name PING_RF_TM  apid 100  service_type 17  subservice 2]
    set psuTm  [dict create tm_name PSU_TM      apid 100  service_type 3   subservice 25]
    return [dict create \
        commandByKey    [dict create "100:17:1" $pingCmd  "100:3:1" $psuCmd] \
        commandsByName  [dict create PING_RF $pingCmd  PSU_SET_VOLTAGE $psuCmd] \
        paramsByCommand [dict create PING_RF [list $pingParam]  PSU_SET_VOLTAGE [list $psuParam]] \
        tmByKey         [dict create "100:17:2" $pingTm  "100:3:25" $psuTm] \
        tmByName        [dict create PING_RF_TM $pingTm  PSU_TM $psuTm] \
        tmParamsByName  [dict create PING_RF_TM [list $pingParam]  PSU_TM [list $psuParam]]]
}
set mibIndex [_buildTestMibIndex]
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

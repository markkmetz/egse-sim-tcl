package require tcltest
namespace import ::tcltest::*

set here [file dirname [file normalize [info script]]]
set root [file dirname $here]

source [file join $root lib egse mib_loader.tcl]
source [file join $root lib egse protocol.tcl]

# Build an in-memory test MIB index matching the APID/service/sub values used below.
# These tests exercise protocol encode/decode logic, not MIB loading.
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

test tc-decode-001 {decode known TC and resolve MIB command} -body {
    set pus0 17
    set serviceType 17
    set subservice 1
    set sourceId 1
    set params [binary format cc 18 52]
    set payload [binary format cccca* $pus0 $serviceType $subservice $sourceId $params]

    set tc [egse::protocol::encodeSpacePacket \
        packet_type 1 \
        apid 100 \
        sequence_count 7 \
        payload $payload]

    set decoded [egse::protocol::decodeTcPacket $tc $mibIndex]
    list \
        [dict get $decoded service_type] \
        [dict get $decoded subservice] \
        [dict get [dict get $decoded command_def] command_name] \
        [binary encode hex [dict get $decoded params]] \
        [dict get $decoded decoded_values echo_data]
} -result {17 1 PING_RF 1234 4660}

test tm-build-001 {build TM packet from MIB parameter definitions} -body {
    set pus0 17
    set params [binary format cc 18 52]
    set payload [binary format cccca* $pus0 17 1 1 $params]
    set tc [egse::protocol::encodeSpacePacket \
        packet_type 1 \
        apid 100 \
        sequence_count 9 \
        payload $payload]
    set decoded [egse::protocol::decodeTcPacket $tc $mibIndex]

    set tm [egse::protocol::buildTmFromMib $decoded $mibIndex 17 2 [dict create echo_data 4660]]
    set tmDecoded [egse::protocol::decodeSpacePacket $tm]
    binary scan [dict get $tmDecoded payload] cccc _ st sst _
    set tail [string range [dict get $tmDecoded payload] 4 end]
    list $st $sst [binary encode hex $tail]
} -result {17 2 1234}

test tc-decode-002 {reject wrong packet type} -body {
    set payload [binary format cccc 17 17 1 1]
    set tm [egse::protocol::encodeSpacePacket \
        packet_type 0 \
        apid 100 \
        sequence_count 1 \
        payload $payload]
    catch {egse::protocol::decodeTcPacket $tm $mibIndex} err
    string match {*Expected TC*} $err
} -result 1

cleanupTests

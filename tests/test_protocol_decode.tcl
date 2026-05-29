package require tcltest
namespace import ::tcltest::*

set here [file dirname [file normalize [info script]]]
set root [file dirname $here]

source [file join $root lib egse mib_loader.tcl]
source [file join $root lib egse protocol.tcl]

set mibIndex [egse::mib::loadMibSet [file join $root examples mibs] generic]

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

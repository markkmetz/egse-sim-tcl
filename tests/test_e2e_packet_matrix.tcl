package require tcltest
namespace import ::tcltest::*

set here [file dirname [file normalize [info script]]]
set root [file dirname $here]

source [file join $root lib egse mib_loader.tcl]
source [file join $root lib egse protocol.tcl]
source [file join $root lib egse dispatcher.tcl]
source [file join $root lib egse transport.tcl]
source [file join $root lib egse plugins rf.tcl]
source [file join $root lib egse plugins power.tcl]

set mibIndex [egse::mib::loadMibSet [file join $root examples mibs] generic]
egse::dispatch::registerHandler rf_ping egse::plugin::rf::action_ping
egse::dispatch::registerHandler psu_set_voltage egse::plugin::power::action_set_voltage

set ::portBase 5900
set ::tcSock ""
set ::tmSock ""
set ::tmBytes ""
set ::done 0
set ::tmMinBytes 0
set ::errCount 0
set ::errReasons {}

proc nextPorts {} {
    set tc $::portBase
    set tm [expr {$::portBase + 1}]
    incr ::portBase 10
    return [list $tc $tm]
}

proc testCfg {tcPort tmPort} {
    return [dict create \
        tc_transport tcp \
        tm_transport tcp \
        tc_host 127.0.0.1 \
        tc_port $tcPort \
        tm_host 127.0.0.1 \
        tm_port $tmPort]
}

proc onTcPacketHarness {cfg mibIndex transport endpoint rawPacket} {
    set rc [catch {
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
    } err]

    if {$rc != 0} {
        incr ::errCount
        lappend ::errReasons $err
    }
}

proc onTmReadableHarness {sock} {
    append ::tmBytes [read $sock]
    if {[string length $::tmBytes] >= $::tmMinBytes} {
        set ::done 1
    }
}

proc startHarness {cfg mibIndex} {
    set ::tmBytes ""
    set ::done 0
    set ::tmMinBytes 0
    set ::errCount 0
    set ::errReasons {}

    egse::transport::start $cfg [list onTcPacketHarness $cfg $mibIndex]

    set ::tmSock [socket 127.0.0.1 [dict get $cfg tm_port]]
    fconfigure $::tmSock -blocking 0 -translation binary -buffering none
    fileevent $::tmSock readable [list onTmReadableHarness $::tmSock]

    set ::tcSock [socket 127.0.0.1 [dict get $cfg tc_port]]
    fconfigure $::tcSock -blocking 0 -translation binary -buffering none
}

proc stopHarness {} {
    if {$::tcSock ne ""} {
        catch {close $::tcSock}
        set ::tcSock ""
    }
    if {$::tmSock ne ""} {
        catch {close $::tmSock}
        set ::tmSock ""
    }
    egse::transport::stop
}

proc sendTcAndWait {packet minTmBytes timeoutMs} {
    set ::tmBytes ""
    set ::done 0
    set ::tmMinBytes $minTmBytes

    puts -nonewline $::tcSock $packet
    flush $::tcSock

    after $timeoutMs { if {!$::done} { set ::done timeout } }
    vwait ::done
    return $::done
}

proc buildTc {serviceType subservice params {apid 100} {sequence 1} {packetType 1}} {
    set payload [binary format cccca* 17 $serviceType $subservice 1 $params]
    return [egse::protocol::encodeSpacePacket \
        packet_type $packetType \
        apid $apid \
        sequence_count $sequence \
        payload $payload]
}

test e2e-valid-001 {rf ping param 0x0000 round-trips} -body {
    lassign [nextPorts] tc tm
    set cfg [testCfg $tc $tm]
    startHarness $cfg $::mibIndex

    set tcPacket [buildTc 17 1 [binary format cc 0 0] 100 11 1]
    set result [sendTcAndWait $tcPacket 12 1200]

    stopHarness

    if {$result eq "timeout"} {
        error "Timed out waiting for TM"
    }

    set decoded [egse::protocol::decodeSpacePacket $::tmBytes]
    binary scan [dict get $decoded payload] cccc _ st sst _
    set tail [binary encode hex [string range [dict get $decoded payload] 4 end]]
    list [dict get $decoded packet_type] $st $sst $tail $::errCount
} -result {0 17 2 0000 0}

test e2e-valid-002 {rf ping param 0x1234 round-trips} -body {
    lassign [nextPorts] tc tm
    set cfg [testCfg $tc $tm]
    startHarness $cfg $::mibIndex

    set tcPacket [buildTc 17 1 [binary format cc 18 52] 100 12 1]
    set result [sendTcAndWait $tcPacket 12 1200]

    stopHarness

    if {$result eq "timeout"} {
        error "Timed out waiting for TM"
    }

    set decoded [egse::protocol::decodeSpacePacket $::tmBytes]
    binary scan [dict get $decoded payload] cccc _ st sst _
    set tail [binary encode hex [string range [dict get $decoded payload] 4 end]]
    list [dict get $decoded packet_type] $st $sst $tail $::errCount
} -result {0 17 2 1234 0}

test e2e-valid-003 {rf ping param 0xABCD round-trips} -body {
    lassign [nextPorts] tc tm
    set cfg [testCfg $tc $tm]
    startHarness $cfg $::mibIndex

    set tcPacket [buildTc 17 1 [binary format cc 171 205] 100 13 1]
    set result [sendTcAndWait $tcPacket 12 1200]

    stopHarness

    if {$result eq "timeout"} {
        error "Timed out waiting for TM"
    }

    set decoded [egse::protocol::decodeSpacePacket $::tmBytes]
    binary scan [dict get $decoded payload] cccc _ st sst _
    set tail [binary encode hex [string range [dict get $decoded payload] 4 end]]
    list [dict get $decoded packet_type] $st $sst $tail $::errCount
} -result {0 17 2 abcd 0}

test e2e-valid-004 {set psu voltage 3300mV round-trips} -body {
    lassign [nextPorts] tc tm
    set cfg [testCfg $tc $tm]
    startHarness $cfg $::mibIndex

    set tcPacket [buildTc 3 1 [binary format cc 12 228] 100 14 1]
    set result [sendTcAndWait $tcPacket 12 1200]

    stopHarness

    if {$result eq "timeout"} {
        error "Timed out waiting for TM"
    }

    set decoded [egse::protocol::decodeSpacePacket $::tmBytes]
    binary scan [dict get $decoded payload] cccc _ st sst _
    set tail [binary encode hex [string range [dict get $decoded payload] 4 end]]
    list [dict get $decoded packet_type] $st $sst $tail $::errCount
} -result {0 3 25 0ce4 0}

test e2e-valid-005 {set psu voltage 5000mV round-trips} -body {
    lassign [nextPorts] tc tm
    set cfg [testCfg $tc $tm]
    startHarness $cfg $::mibIndex

    set tcPacket [buildTc 3 1 [binary format cc 19 136] 100 15 1]
    set result [sendTcAndWait $tcPacket 12 1200]

    stopHarness

    if {$result eq "timeout"} {
        error "Timed out waiting for TM"
    }

    set decoded [egse::protocol::decodeSpacePacket $::tmBytes]
    binary scan [dict get $decoded payload] cccc _ st sst _
    set tail [binary encode hex [string range [dict get $decoded payload] 4 end]]
    list [dict get $decoded packet_type] $st $sst $tail $::errCount
} -result {0 3 25 1388 0}

test e2e-anti-001 {unsupported command returns negative TM and no crash} -body {
    lassign [nextPorts] tc tm
    set cfg [testCfg $tc $tm]
    startHarness $cfg $::mibIndex

    set tcPacket [buildTc 99 1 [binary format cc 1 2] 100 16 1]
    set result [sendTcAndWait $tcPacket 10 1200]

    stopHarness

    if {$result eq "timeout"} {
        error "Timed out waiting for negative TM"
    }

    set decoded [egse::protocol::decodeSpacePacket $::tmBytes]
    binary scan [dict get $decoded payload] cccc _ st sst _
    list [dict get $decoded packet_type] $st $sst [string length [dict get $decoded payload]] $::errCount
} -result {0 1 8 4 0}

test e2e-anti-002 {bad packet_type is rejected and next valid TC still works} -body {
    lassign [nextPorts] tc tm
    set cfg [testCfg $tc $tm]
    startHarness $cfg $::mibIndex

    set badPacket [buildTc 17 1 [binary format cc 7 8] 100 17 0]
    set badResult [sendTcAndWait $badPacket 1 400]
    set errsAfterBad $::errCount

    set goodPacket [buildTc 17 1 [binary format cc 7 8] 100 18 1]
    set goodResult [sendTcAndWait $goodPacket 12 1200]

    stopHarness

    if {$goodResult eq "timeout"} {
        error "Simulator did not recover after malformed TC"
    }

    set decoded [egse::protocol::decodeSpacePacket $::tmBytes]
    binary scan [dict get $decoded payload] cccc _ st sst _
    list $badResult $errsAfterBad [dict get $decoded packet_type] $st $sst
} -result {timeout 1 0 17 2}

test e2e-anti-003 {length mismatch packet is handled without TM} -body {
    lassign [nextPorts] tc tm
    set cfg [testCfg $tc $tm]
    startHarness $cfg $::mibIndex

    set goodPacket [buildTc 17 1 [binary format cc 10 11] 100 19 1]
    set badPacket [string range $goodPacket 0 end-1]

    set result [sendTcAndWait $badPacket 1 400]
    set errors $::errCount

    stopHarness

    list $result $errors
} -result {timeout 1}

test e2e-anti-004 {too-short TC secondary header is handled without TM} -body {
    lassign [nextPorts] tc tm
    set cfg [testCfg $tc $tm]
    startHarness $cfg $::mibIndex

    set shortPayload [binary format ccc 17 17 1]
    set badPacket [egse::protocol::encodeSpacePacket \
        packet_type 1 \
        apid 100 \
        sequence_count 20 \
        payload $shortPayload]

    set result [sendTcAndWait $badPacket 1 400]
    set errors $::errCount

    stopHarness

    list $result $errors
} -result {timeout 1}

test e2e-anti-005 {missing command parameter bytes are handled without exiting} -body {
    lassign [nextPorts] tc tm
    set cfg [testCfg $tc $tm]
    startHarness $cfg $::mibIndex

    # SET_PSU_VOLTAGE expects two bytes, but this packet sends one.
    set badPacket [buildTc 3 1 [binary format c 9] 100 21 1]
    set badResult [sendTcAndWait $badPacket 1 400]
    set errsAfterBad $::errCount

    set goodPacket [buildTc 3 1 [binary format cc 12 228] 100 22 1]
    set goodResult [sendTcAndWait $goodPacket 12 1200]

    stopHarness

    if {$goodResult eq "timeout"} {
        error "Simulator did not recover after short-parameter TC"
    }

    set decoded [egse::protocol::decodeSpacePacket $::tmBytes]
    binary scan [dict get $decoded payload] cccc _ st sst _
    set tail [binary encode hex [string range [dict get $decoded payload] 4 end]]
    list $badResult $errsAfterBad [dict get $decoded packet_type] $st $sst $tail
} -result {timeout 1 0 3 25 0ce4}

cleanupTests

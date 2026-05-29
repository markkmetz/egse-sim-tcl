#!/usr/bin/env tclsh

set scriptDir [file dirname [file normalize [info script]]]
set rootDir [file dirname $scriptDir]

source [file join $rootDir lib egse config.tcl]
source [file join $rootDir lib egse logging.tcl]
source [file join $rootDir lib egse mib_loader.tcl]
source [file join $rootDir lib egse protocol.tcl]
source [file join $rootDir lib egse dispatcher.tcl]
source [file join $rootDir lib egse egse_registry.tcl]
source [file join $rootDir lib egse transport.tcl]

set cfgPath ""
if {[llength $argv] > 0} {
    set cfgPath [lindex $argv 0]
}

set cfg [egse::config::load $cfgPath]
set cfg [egse::registry::activate $rootDir $cfg]

set mibRoot [dict get $cfg mib_root]
if {[file pathtype $mibRoot] ne "absolute"} {
    set mibRoot [file join $rootDir $mibRoot]
}
set mibSet [dict get $cfg mib_set]
set mibIndex [egse::mib::loadMibSet $mibRoot $mibSet]

set logFile [dict get $cfg log_file]
if {[file pathtype $logFile] ne "absolute"} {
    set logFile [file join $rootDir $logFile]
}
egse::log::init \
    $logFile \
    [dict get $cfg log_rotate_bytes] \
    [dict get $cfg log_rotate_files]
egse::log::event info "egse-start type=[dict get $cfg egse_type] mib_set=$mibSet"

# Handlers are registered by egse::registry::activate.

proc ::onTcPacket {cfg mibIndex transport endpoint rawPacket} {
    catch {
        set decoded [egse::protocol::decodeTcPacket $rawPacket $mibIndex]
        egse::log::packet RX $transport $endpoint $rawPacket $decoded

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
        egse::log::packet TX [dict get $cfg tm_transport] [dict get $cfg tm_port] $tmPacket $actionResult
    } err

    if {$err ne ""} {
        egse::log::event error "tc-processing-failed reason=$err"
    }
}

egse::transport::start $cfg [list ::onTcPacket $cfg $mibIndex]

proc ::shutdown {} {
    egse::transport::stop
    egse::log::event info "egse-stop"
    egse::log::closeLogger
    set ::forever 0
}

if {[catch {package require Tclx}]} {
    # No extra signal package available; rely on process termination.
} else {
    signal trap SIGINT ::shutdown
    signal trap SIGTERM ::shutdown
}

puts "EGSE simulator running mode=[dict get $cfg transport_mode] TC=[dict get $cfg tc_transport]:[dict get $cfg tc_host]:[dict get $cfg tc_port] TM=[dict get $cfg tm_transport]:[dict get $cfg tm_host]:[dict get $cfg tm_port]"

set forever 1
vwait forever

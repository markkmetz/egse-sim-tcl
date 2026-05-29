#!/usr/bin/env tclsh

# Child worker started by egse_sim supervisor.
# Expects one startup file argument that defines EGSE_CONFIG.

set scriptDir [file dirname [file normalize [info script]]]
set rootDir [file dirname $scriptDir]

source [file join $rootDir lib egse logging.tcl]
source [file join $rootDir lib egse mib_loader.tcl]
source [file join $rootDir lib egse protocol.tcl]
source [file join $rootDir lib egse dispatcher.tcl]
source [file join $rootDir lib egse egse_registry.tcl]
source [file join $rootDir lib egse transport.tcl]

set startupPath ""
if {[llength $argv] > 0} {
    set startupPath [lindex $argv 0]
}

if {$startupPath eq ""} {
    error "Startup file argument is required"
}
if {![file exists $startupPath]} {
    error "Startup file not found: $startupPath"
}

catch {unset ::EGSE_CONFIG}
catch {unset ::EGSE_SIMULATORS}
uplevel #0 [list source $startupPath]

if {![info exists ::EGSE_CONFIG]} {
    error "Startup file must define EGSE_CONFIG"
}
if {[info exists ::EGSE_SIMULATORS]} {
    error "Startup file for worker must define EGSE_CONFIG only (not EGSE_SIMULATORS)"
}

set configOverrides $::EGSE_CONFIG

set egseType [expr {[dict exists $configOverrides egse_type] ? [dict get $configOverrides egse_type] : "generic"}]

set egsePath [egse::registry::_egsePath $rootDir $egseType]
if {![file exists $egsePath]} {
    error "EGSE file not found: $egsePath"
}
source $egsePath

set cfg [::egse::type::${egseType}::config]
dict for {k v} $configOverrides {
    dict set cfg $k $v
}

set settingsProc [format "::egse::type::%s::settings" $egseType]
set registerProc [format "::egse::type::%s::register" $egseType]

if {[llength [info procs $settingsProc]] == 0} {
    error "EGSE file $egsePath must define proc $settingsProc"
}
if {[llength [info procs $registerProc]] == 0} {
    error "EGSE file $egsePath must define proc $registerProc"
}

set egseSettings [{*}$settingsProc]
dict for {k v} $egseSettings {
    if {![dict exists $cfg $k]} {
        dict set cfg $k $v
    }
}

{*}$registerProc $rootDir

if {[dict exists $cfg tc_listener_file]} {
    set listenerFile [dict get $cfg tc_listener_file]
    if {$listenerFile ne ""} {
        if {[file pathtype $listenerFile] ne "absolute"} {
            set listenerFile [file join $rootDir $listenerFile]
        }
        if {![file exists $listenerFile]} {
            error "TC listener file not found: $listenerFile"
        }
        source $listenerFile
    }
}

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

proc ::onTcPacket {cfg mibIndex transport endpoint rawPacket} {
    catch {
        set binaryRc [catch {
            set decoded [egse::protocol::decodeTcPacket $rawPacket $mibIndex]
        } binaryErr]

        puts "DEBUG worker: binary decode rc=$binaryRc"
        if {$binaryRc == 0} {
            puts "DEBUG worker: binary decode ok command_def_empty=[expr {[dict get $decoded command_def] eq {}}]"
        } else {
            puts "DEBUG worker: binary decode failed err=$binaryErr"
        }

        if {$binaryRc != 0 || [dict get $decoded command_def] eq ""} {
            puts "DEBUG worker: attempting ASCII decode..."
            set asciiRc [catch {
                set decoded [egse::protocol::decodeAsciiTcPacket $rawPacket $mibIndex]
            } asciiErr]

            puts "DEBUG worker: ascii decode rc=$asciiRc"
            if {$asciiRc == 0} {
                set cmdDef [dict get $decoded command_def]
                puts "DEBUG worker: ascii decode ok command_def=[expr {$cmdDef ne {} ? [dict get $cmdDef command_name] : {EMPTY}}]"
            } else {
                puts "DEBUG worker: ascii decode failed err=$asciiErr"
            }

            if {$asciiRc != 0 && $binaryRc != 0} {
                error "binary decode failed: $binaryErr ; ascii decode failed: $asciiErr"
            }
        }

        set finalCmdDef [dict get $decoded command_def]
        puts "DEBUG worker: final command_def=[expr {$finalCmdDef ne {} ? [dict get $finalCmdDef command_name] : {EMPTY}}]"
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

puts "EGSE worker running mode=[dict get $cfg transport_mode] TC=[dict get $cfg tc_transport]:[dict get $cfg tc_host]:[dict get $cfg tc_port] TM=[dict get $cfg tm_transport]:[dict get $cfg tm_host]:[dict get $cfg tm_port]"

set forever 1
vwait forever

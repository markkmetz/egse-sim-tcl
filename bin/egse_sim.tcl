#!/usr/bin/env tclsh

# Supervisor-only launcher.
#
# This file only starts multiple EGSE child simulators.
# Each child simulator is started by lib/egse_worker.tcl with one startup file.
#
# Option A: edit EGSE_SIMULATORS below (inline launcher)
# Option B: pass a launcher file path that defines EGSE_SIMULATORS
#
# Example:
#   tclsh bin/egse_sim.tcl
#   tclsh bin/egse_sim.tcl path/to/launcher.tcl

set EGSE_SIMULATORS [list]
# lappend EGSE_SIMULATORS "bin/esa_tc_demo.tcl"
# lappend EGSE_SIMULATORS "bin/egse2_demo.tcl"

proc ::startSupervisor {rootDir simulatorFiles} {
    set worker [file join $rootDir lib egse_worker.tcl]
    if {![file exists $worker]} {
        error "Worker script not found: $worker"
    }

    set ::childPids [list]

    foreach profile $simulatorFiles {
        set profilePath $profile
        if {[file pathtype $profilePath] ne "absolute"} {
            set profilePath [file join $rootDir $profilePath]
        }
        if {![file exists $profilePath]} {
            error "Supervisor startup file not found: $profilePath"
        }

        set pid [exec tclsh $worker $profilePath &]
        lappend ::childPids $pid
        puts "Started simulator pid=$pid config=$profilePath"
    }

    proc ::shutdownSupervisor {} {
        foreach pid $::childPids {
            catch {exec kill $pid}
        }
        set ::forever 0
    }

    if {![catch {package require Tclx}]} {
        signal trap SIGINT ::shutdownSupervisor
        signal trap SIGTERM ::shutdownSupervisor
    }

    puts "Supervisor running children=[llength $::childPids]"
    set forever 1
    vwait forever
    exit 0
}

set scriptDir [file dirname [file normalize [info script]]]
set rootDir [file dirname $scriptDir]

set launcherPath ""
if {[llength $argv] > 0} {
    set launcherPath [lindex $argv 0]
}

if {$launcherPath ne ""} {
    if {![file exists $launcherPath]} {
        error "Launcher file not found: $launcherPath"
    }
    catch {unset ::EGSE_SIMULATORS}
    uplevel #0 [list source $launcherPath]
    if {[info exists ::EGSE_SIMULATORS]} {
        set EGSE_SIMULATORS $::EGSE_SIMULATORS
    }
}

if {[llength $EGSE_SIMULATORS] == 0} {
    error "Supervisor mode requires EGSE_SIMULATORS. Add lappend lines at top of bin/egse_sim.tcl or pass a launcher file defining EGSE_SIMULATORS."
}

::startSupervisor $rootDir $EGSE_SIMULATORS

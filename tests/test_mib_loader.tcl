package require tcltest
namespace import ::tcltest::*

set here [file dirname [file normalize [info script]]]
set root [file dirname $here]

source [file join $root lib egse mib_loader.tcl]

test mib-load-001 {load sample MIB set} -body {
    set idx [egse::mib::loadMibSet [file join $root examples mibs] generic]
    list \
        [dict exists $idx commandByKey 100:17:1] \
        [dict exists $idx commandByKey 100:3:1] \
        [llength [dict get $idx tables ccf.dat rows]]
} -result {1 1 2}

test mib-load-002 {command params index is built} -body {
    set idx [egse::mib::loadMibSet [file join $root examples mibs] generic]
    llength [dict get $idx paramsByCommand PING_RF]
} -result 1

test mib-load-003 {tm indexes and MIB set listing are available} -body {
    set idx [egse::mib::loadMibSet [file join $root examples mibs] generic]
    set pos [lsearch -exact [egse::mib::listMibSets [file join $root examples mibs]] generic]
    list \
        [dict exists $idx tmByKey 100:17:2] \
        [expr {$pos >= 0}]
} -result {1 1}

cleanupTests

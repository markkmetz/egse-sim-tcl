package require tcltest
namespace import ::tcltest::*

set here [file dirname [file normalize [info script]]]
set root [file dirname $here]

source [file join $root lib egse mib_loader.tcl]

test mib-load-001 {load SCOS2000 MIB set — known keys present} -body {
    set idx [egse::mib::loadMibSet [file join $root MIBS] generic]
    list \
        [dict exists $idx commandByKey 17:2:1] \
        [dict exists $idx commandByKey 17:3:1] \
        [llength [dict keys [dict get $idx commandsByName]]]
} -result {1 1 139}

test mib-load-002 {command params index built for S2KTC001} -body {
    set idx [egse::mib::loadMibSet [file join $root MIBS] generic]
    llength [dict get $idx paramsByCommand S2KTC001]
} -result 3

test mib-load-003 {tm indexes and MIB set listing available} -body {
    set idx [egse::mib::loadMibSet [file join $root MIBS] generic]
    set pos [lsearch -exact [egse::mib::listMibSets [file join $root MIBS]] generic]
    list \
        [dict exists $idx tmByKey 281:3:25] \
        [expr {$pos >= 0}]
} -result {1 1}

cleanupTests

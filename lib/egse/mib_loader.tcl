namespace eval egse::mib {
    variable requiredFiles [list ccf.dat cdf.dat pid.dat plf.dat pcf.dat]

    proc _parseDelimitedDat {filePath} {
        set fh [open $filePath r]
        set rows {}
        set columns {}
        while {[gets $fh line] >= 0} {
            set trimmed [string trim $line]
            if {$trimmed eq ""} {
                continue
            }
            if {[string index $trimmed 0] eq ";"} {
                continue
            }
            if {[string index $trimmed 0] eq "#"} {
                set header [string range $trimmed 1 end]
                set columns [split $header |]
                set columns [lmap c $columns {string trim $c}]
                continue
            }
            if {![llength $columns]} {
                error "Missing header row in $filePath (expected #col1|col2|...)"
            }
            set values [split $trimmed |]
            set values [lmap v $values {string trim $v}]
            if {[llength $values] != [llength $columns]} {
                error "Column count mismatch in $filePath line: $line"
            }
            set row [dict create]
            foreach c $columns v $values {
                dict set row $c $v
            }
            lappend rows $row
        }
        close $fh
        return [dict create columns $columns rows $rows]
    }

    proc loadMibSet {mibRoot mibSet} {
        variable requiredFiles
        set mibDir [file join $mibRoot $mibSet]
        if {![file isdirectory $mibDir]} {
            error "MIB directory does not exist: $mibDir"
        }

        set tables [dict create]
        foreach f $requiredFiles {
            set p [file join $mibDir $f]
            if {![file exists $p]} {
                error "Required MIB file missing: $p"
            }
            dict set tables $f [_parseDelimitedDat $p]
        }

        return [buildIndex $tables]
    }

    proc listMibSets {mibRoot} {
        if {![file isdirectory $mibRoot]} {
            return {}
        }
        set sets {}
        foreach entry [glob -nocomplain -directory $mibRoot *] {
            if {[file isdirectory $entry]} {
                lappend sets [file tail $entry]
            }
        }
        return [lsort $sets]
    }

    proc validateTables {tables} {
        set commandNames [dict create]
        foreach row [dict get $tables ccf.dat rows] {
            dict set commandNames [dict get $row command_name] 1
        }

        foreach row [dict get $tables cdf.dat rows] {
            set cmd [dict get $row command_name]
            if {![dict exists $commandNames $cmd]} {
                error "cdf.dat references unknown command_name=$cmd"
            }
        }

        set tmNames [dict create]
        foreach row [dict get $tables pid.dat rows] {
            dict set tmNames [dict get $row tm_name] 1
        }

        foreach row [dict get $tables plf.dat rows] {
            set tm [dict get $row tm_name]
            if {![dict exists $tmNames $tm]} {
                error "plf.dat references unknown tm_name=$tm"
            }
        }
    }

    proc buildIndex {tables} {
        validateTables $tables

        set commandByKey [dict create]
        set commandsByName [dict create]

        foreach row [dict get $tables ccf.dat rows] {
            set name [dict get $row command_name]
            set apid [dict get $row apid]
            set st [dict get $row service_type]
            set sst [dict get $row subservice]
            set key [format "%s:%s:%s" $apid $st $sst]
            dict set commandByKey $key $row
            dict set commandsByName $name $row
        }

        set paramsByCommand [dict create]
        foreach row [dict get $tables cdf.dat rows] {
            set cmd [dict get $row command_name]
            dict lappend paramsByCommand $cmd $row
        }

        set tmByKey [dict create]
        set tmByName [dict create]
        foreach row [dict get $tables pid.dat rows] {
            set name [dict get $row tm_name]
            set apid [dict get $row apid]
            set st [dict get $row service_type]
            set sst [dict get $row subservice]
            set key [format "%s:%s:%s" $apid $st $sst]
            dict set tmByKey $key $row
            dict set tmByName $name $row
        }

        set tmParamsByName [dict create]
        foreach row [dict get $tables plf.dat rows] {
            set tmName [dict get $row tm_name]
            dict lappend tmParamsByName $tmName $row
        }

        return [dict create \
            tables $tables \
            commandByKey $commandByKey \
            commandsByName $commandsByName \
            paramsByCommand $paramsByCommand \
            tmByKey $tmByKey \
            tmByName $tmByName \
            tmParamsByName $tmParamsByName]
    }
}

package provide egse::mib 0.1.0

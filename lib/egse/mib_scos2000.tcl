namespace eval egse::mib::scos2000 {
    # SCOS2000 ASCII .dat file parser
    # All files are tab-delimited, one record per line.
    # Comment lines start with ; or #. Blank lines are skipped.

    proc _col {cols idx} {
        # Return field at index idx, or empty string if out of range.
        if {$idx < [llength $cols]} {
            return [string trim [lindex $cols $idx]]
        }
        return ""
    }

    proc splitDatLine {line} {
        # Split on tabs only — preserves empty fields (adjacent tabs) and multi-word values.
        return [split $line "\t"]
    }

    proc readDatFile {filePath} {
        if {![file exists $filePath]} {
            return {}
        }
        set lines {}
        set fh [open $filePath r]
        while {[gets $fh line] >= 0} {
            set trimmed [string trim $line]
            if {$trimmed eq ""} {continue}
            if {[string index $trimmed 0] eq ";"} {continue}
            if {[string index $trimmed 0] eq "#"} {continue}
            lappend lines $line
        }
        close $fh
        return $lines
    }

    proc parseCcfLines {lines} {
        # CCF columns: id, name, description, [spare], critical, header,
        #              service_type, subservice, apid, ...
        set result [dict create]
        foreach line $lines {
            set cols [splitDatLine $line]
            set tcId [_col $cols 0]
            if {$tcId eq ""} {continue}
            dict set result $tcId [dict create \
                id           $tcId \
                name         [_col $cols 1] \
                description  [_col $cols 2] \
                critical     [_col $cols 4] \
                header       [_col $cols 5] \
                service_type [_col $cols 6] \
                subservice   [_col $cols 7] \
                apid         [_col $cols 8]]
        }
        return $result
    }

    proc parseCdfLines {lines tcByIdRef} {
        # CDF columns: tc_id, kind, description, bit_length, bit_offset, [spare], param_id, type, ...
        # Mutates the tcById dict in the caller's scope via upvar.
        upvar 1 $tcByIdRef tcById
        foreach line $lines {
            set cols [splitDatLine $line]
            set tcId [_col $cols 0]
            if {$tcId eq "" || ![dict exists $tcById $tcId]} {continue}
            set param [dict create \
                kind      [_col $cols 1] \
                name      [_col $cols 2] \
                bitLength [_col $cols 3] \
                bitOffset [_col $cols 4] \
                paramId   [_col $cols 6] \
                type      [_col $cols 7]]
            # dict lappend only operates at one level; get entry, mutate, put back.
            set entry [dict get $tcById $tcId]
            dict lappend entry params $param
            dict set tcById $tcId $entry
        }
    }

    proc parsePidLines {lines} {
        # PID columns: service_type, subservice, apid, pi1_off, pi2_off, spid, description, ...
        # Returns list: {byKey bySpid}
        # byKey  keyed by apid:service_type:subservice  (matches buildIndex convention)
        # bySpid keyed by spid
        set byKey  [dict create]
        set bySpid [dict create]
        foreach line $lines {
            set cols [splitDatLine $line]
            set service_type [_col $cols 0]
            set subservice   [_col $cols 1]
            set apid         [_col $cols 2]
            set spid         [_col $cols 5]
            if {$service_type eq "" || $apid eq "" || $spid eq ""} {continue}
            set key [format "%s:%s:%s" $apid $service_type $subservice]
            set entry [dict create \
                service_type $service_type \
                subservice   $subservice \
                apid         $apid \
                spid         $spid \
                description  [_col $cols 6]]
            dict set byKey  $key  $entry
            dict set bySpid $spid $entry
        }
        return [list $byKey $bySpid]
    }

    proc parsePlfLines {lines pidBySpidRef} {
        # PLF columns: param_name, spid, offby, offbi, nbocc, lgocc, time, tdelta
        # Mutates pidBySpid in the caller's scope via upvar.
        upvar 1 $pidBySpidRef pidBySpid
        foreach line $lines {
            set cols [splitDatLine $line]
            set spid [_col $cols 1]
            if {$spid eq "" || ![dict exists $pidBySpid $spid]} {continue}
            set param [dict create \
                paramName [_col $cols 0] \
                offby     [_col $cols 2] \
                offbi     [_col $cols 3]]
            # dict lappend only operates at one level; get entry, mutate, put back.
            set entry [dict get $pidBySpid $spid]
            dict lappend entry params $param
            dict set pidBySpid $spid $entry
        }
    }

    proc parsePcfLines {lines} {
        # PCF columns: name, description, pid, unit, ptc, pfc, width, ...
        set result [dict create]
        foreach line $lines {
            set cols [splitDatLine $line]
            set paramId [_col $cols 0]
            if {$paramId eq ""} {continue}
            dict set result $paramId [dict create \
                paramId     $paramId \
                description [_col $cols 1] \
                ptc         [_col $cols 4] \
                pfc         [_col $cols 5] \
                bitLength   [_col $cols 6]]
        }
        return $result
    }

    proc parseCpcLines {lines} {
        # CPC columns: param_name, descr, ptc, pfc, dispfmt, radix, unit, categ, ...
        set result [dict create]
        foreach line $lines {
            set cols [splitDatLine $line]
            set paramId [_col $cols 0]
            if {$paramId eq ""} {continue}
            dict set result $paramId [dict create \
                paramId     $paramId \
                description [_col $cols 1] \
                ptc         [_col $cols 2] \
                pfc         [_col $cols 3] \
                unit        [_col $cols 6]]
        }
        return $result
    }

    proc loadMibSet {mibRoot mibSet} {
        set mibDir [file join $mibRoot $mibSet]
        if {![file isdirectory $mibDir]} {
            error "MIB directory does not exist: $mibDir"
        }

        set ccfLines [readDatFile [file join $mibDir ccf.dat]]
        set cdfLines [readDatFile [file join $mibDir cdf.dat]]
        set pidLines [readDatFile [file join $mibDir pid.dat]]
        set plfLines [readDatFile [file join $mibDir plf.dat]]
        set pcfLines [readDatFile [file join $mibDir pcf.dat]]
        set cpcLines [readDatFile [file join $mibDir cpc.dat]]

        # Parse TC tables.  parseCdfLines uses upvar to mutate tcById directly.
        set tcById [parseCcfLines $ccfLines]
        parseCdfLines $cdfLines tcById

        # Parse TM tables.  parsePlfLines uses upvar to mutate pidBySpid directly.
        lassign [parsePidLines $pidLines] pidByKey pidBySpid
        parsePlfLines $plfLines pidBySpid

        # Rebuild pidByKey from the (now-updated) pidBySpid so params are present.
        dict for {spid entry} $pidBySpid {
            set key [format "%s:%s:%s" \
                [dict get $entry apid] \
                [dict get $entry service_type] \
                [dict get $entry subservice]]
            dict set pidByKey $key $entry
        }

        set pcfById [parsePcfLines $pcfLines]
        set cpcById [parseCpcLines $cpcLines]

        return [dict create \
            tcById    $tcById \
            pidByKey  $pidByKey \
            pidBySpid $pidBySpid \
            pcfById   $pcfById \
            cpcById   $cpcById]
    }
}

package provide egse::mib::scos2000 0.1.0

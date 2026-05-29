namespace eval egse::registry {
    proc _egseSearchPaths {rootDir} {
        return [list [file join $rootDir lib] [file join $rootDir bin]]
    }

    proc _egsePath {rootDir egseType} {
        foreach baseDir [_egseSearchPaths $rootDir] {
            set p [file join $baseDir ${egseType}.tcl]
            if {[file exists $p]} {
                return $p
            }
        }
        # Return preferred location for error messages when not found.
        return [file join $rootDir lib ${egseType}.tcl]
    }

    proc activate {rootDir cfg} {
        set egseType [dict get $cfg egse_type]
        set egsePath [_egsePath $rootDir $egseType]
        if {![file exists $egsePath]} {
            set known [knownTypes $rootDir]
            if {[llength $known]} {
                error "Unknown egse_type '$egseType'. Available EGSEs: [join $known {, }]"
            }
            error "Unknown egse_type '$egseType'. No EGSE files found in lib/ or bin/"
        }

        source $egsePath
        set settingsProc [format "::egse::type::%s::settings" $egseType]
        set registerProc [format "::egse::type::%s::register" $egseType]

        if {[llength [info procs $settingsProc]] == 0} {
            error "EGSE file $egsePath must define proc $settingsProc"
        }
        if {[llength [info procs $registerProc]] == 0} {
            error "EGSE file $egsePath must define proc $registerProc"
        }

        # EGSE defaults are applied only for keys not already set by config.
        set egseSettings [{*}$settingsProc]
        dict for {k v} $egseSettings {
            if {![dict exists $cfg $k]} {
                dict set cfg $k $v
            }
        }

        {*}$registerProc $rootDir
        return $cfg
    }

    proc knownTypes {rootDir} {
        set out {}
        foreach egseDir [_egseSearchPaths $rootDir] {
            if {![file isdirectory $egseDir]} {
                continue
            }
            foreach p [glob -nocomplain -directory $egseDir *.tcl] {
                set basename [file rootname [file tail $p]]
                # Exclude launcher/demo startup scripts from bin.
                if {$basename ni {egse_sim esa_tc_demo egse2_demo}} {
                    lappend out $basename
                }
            }
        }
        return [lsort -unique $out]
    }
}

package provide egse::registry 0.1.0

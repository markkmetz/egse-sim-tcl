namespace eval egse::registry {
    proc _egsePath {rootDir egseType} {
        return [file join $rootDir lib egse egse_types ${egseType}.tcl]
    }

    proc activate {rootDir cfg} {
        set egseType [dict get $cfg egse_type]
        set egsePath [_egsePath $rootDir $egseType]
        if {![file exists $egsePath]} {
            set known [knownTypes $rootDir]
            if {[llength $known]} {
                error "Unknown egse_type '$egseType'. Available EGSEs: [join $known {, }]"
            }
            error "Unknown egse_type '$egseType'. No EGSE files found under lib/egse/egse_types"
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
        set egseDir [file join $rootDir lib egse egse_types]
        if {![file isdirectory $egseDir]} {
            return {}
        }

        set out {}
        foreach p [glob -nocomplain -directory $egseDir *.tcl] {
            lappend out [file rootname [file tail $p]]
        }
        return [lsort $out]
    }
}

package provide egse::registry 0.1.0

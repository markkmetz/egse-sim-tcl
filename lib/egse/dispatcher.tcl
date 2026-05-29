namespace eval egse::dispatch {
    variable handlers [dict create]
    variable commandListeners [dict create]

    proc registerHandler {actionName cmdPrefix} {
        variable handlers
        dict set handlers $actionName $cmdPrefix
    }

    proc registerCommandListener {commandName cmdPrefix {argStyle params}} {
        variable commandListeners

        if {$argStyle ni {params decodedTc}} {
            error "Unsupported listener argStyle=$argStyle (expected params or decodedTc)"
        }
        if {[llength [info commands $cmdPrefix]] == 0} {
            error "Listener proc not found: $cmdPrefix"
        }

        set listener [dict create cmd $cmdPrefix argStyle $argStyle]
        dict lappend commandListeners $commandName $listener
    }

    proc unregisterCommandListener {commandName cmdPrefix} {
        variable commandListeners

        if {![dict exists $commandListeners $commandName]} {
            return
        }

        set kept [list]
        foreach listener [dict get $commandListeners $commandName] {
            if {[dict get $listener cmd] ne $cmdPrefix} {
                lappend kept $listener
            }
        }

        if {[llength $kept] == 0} {
            dict unset commandListeners $commandName
        } else {
            dict set commandListeners $commandName $kept
        }
    }

    proc clearCommandListeners {{commandName ""}} {
        variable commandListeners

        if {$commandName eq ""} {
            set commandListeners [dict create]
            return
        }

        if {[dict exists $commandListeners $commandName]} {
            dict unset commandListeners $commandName
        }
    }

    proc listCommandListeners {commandName} {
        variable commandListeners

        if {![dict exists $commandListeners $commandName]} {
            return [list]
        }

        set procs [list]
        foreach listener [dict get $commandListeners $commandName] {
            lappend procs [dict get $listener cmd]
        }
        return $procs
    }

    proc registerListenerByProcName {procName {argStyle params}} {
        # Convenience adapter for procs named like on_S2KTC001.
        if {![regexp {^on_(.+)$} $procName -> commandName]} {
            error "Expected listener proc name on_<COMMAND_ID>, got $procName"
        }
        registerCommandListener $commandName $procName $argStyle
    }

    proc _invokeCommandListeners {decodedTc} {
        variable commandListeners

        set commandDef [dict get $decodedTc command_def]
        if {$commandDef eq ""} {
            return
        }

        set commandName [dict get $commandDef command_name]
        if {![dict exists $commandListeners $commandName]} {
            return
        }

        set decodedValues [dict create]
        if {[dict exists $decodedTc decoded_values]} {
            set decodedValues [dict get $decodedTc decoded_values]
        }

        foreach listener [dict get $commandListeners $commandName] {
            set cmdPrefix [dict get $listener cmd]
            set argStyle [dict get $listener argStyle]
            if {$argStyle eq "decodedTc"} {
                set rc [catch [list {*}$cmdPrefix $decodedTc] err]
            } else {
                set rc [catch [list {*}$cmdPrefix $decodedValues] err]
            }

            if {$rc != 0} {
                puts "WARN: TC listener failed command=$commandName listener=$cmdPrefix reason=$err"
            }
        }
    }

    proc handleTc {decodedTc} {
        variable handlers

        if {[dict get $decodedTc command_def] eq ""} {
            return [dict create \
                status unsupported \
                tm_service_type 1 \
                tm_subservice 8 \
                tm_param_values [dict create code 1]]
        }

        _invokeCommandListeners $decodedTc

        set actionName [dict get [dict get $decodedTc command_def] action]
        if {![dict exists $handlers $actionName]} {
            return [dict create \
                status missing_handler \
                tm_service_type 1 \
                tm_subservice 8 \
                tm_param_values [dict create code 2]]
        }

        set handler [dict get $handlers $actionName]
        return [{*}$handler $decodedTc]
    }
}

package provide egse::dispatch 0.1.0

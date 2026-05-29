namespace eval egse::dispatch {
    variable handlers [dict create]

    proc registerHandler {actionName cmdPrefix} {
        variable handlers
        dict set handlers $actionName $cmdPrefix
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

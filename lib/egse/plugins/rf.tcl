namespace eval egse::plugin::rf {
    proc action_ping {decodedTc} {
        # Stub RF action: echo decoded TC values back into TM payload values.
        set values [dict get $decodedTc decoded_values]
        if {![dict size $values]} {
            dict set values echo_data 0
        }
        return [dict create \
            status ok \
            tm_service_type 17 \
            tm_subservice 2 \
            tm_param_values $values]
    }
}

package provide egse::plugin::rf 0.1.0

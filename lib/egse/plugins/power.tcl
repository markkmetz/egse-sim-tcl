namespace eval egse::plugin::power {
    proc action_set_voltage {decodedTc} {
        set values [dict get $decodedTc decoded_values]
        if {![dict exists $values voltage_mv]} {
            dict set values voltage_mv 0
        }
        return [dict create \
            status ok \
            tm_service_type 3 \
            tm_subservice 25 \
            tm_param_values [dict create voltage_mv [dict get $values voltage_mv]]]
    }
}

package provide egse::plugin::power 0.1.0

namespace eval ::egse::type::generic {
    proc settings {} {
        return [dict create \
            mib_set generic \
            egse_type generic]
    }

    proc action_rf_ping {decodedTc} {
        # Echo decoded TC values back into TM payload values.
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

    proc action_psu_set_voltage {decodedTc} {
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

    proc register {rootDir} {
        egse::dispatch::registerHandler rf_ping ::egse::type::generic::action_rf_ping
        egse::dispatch::registerHandler psu_set_voltage ::egse::type::generic::action_psu_set_voltage
    }
}

package provide egse::type::generic 0.1.0

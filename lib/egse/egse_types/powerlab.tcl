namespace eval ::egse::type::powerlab {
    proc settings {} {
        return [dict create \
            mib_set powerlab \
            egse_type powerlab]
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
        egse::dispatch::registerHandler psu_set_voltage ::egse::type::powerlab::action_psu_set_voltage
    }
}

package provide egse::type::powerlab 0.1.0

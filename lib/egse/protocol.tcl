namespace eval egse::protocol {
    proc _u16be {hi lo} {
        return [expr {(($hi & 0xFF) << 8) | ($lo & 0xFF)}]
    }

    proc _packByte {value} {
        set v [expr {$value & 0xFF}]
        if {$v > 127} {
            set v [expr {$v - 256}]
        }
        return [binary format c $v]
    }

    proc _packU16be {value} {
        set hi [expr {($value >> 8) & 0xFF}]
        set lo [expr {$value & 0xFF}]
        return "[_packByte $hi][_packByte $lo]"
    }

    proc _u32be {b0 b1 b2 b3} {
        return [expr {(($b0 & 0xFF) << 24) | (($b1 & 0xFF) << 16) | (($b2 & 0xFF) << 8) | ($b3 & 0xFF)}]
    }

    proc _packU32be {value} {
        set b0 [expr {($value >> 24) & 0xFF}]
        set b1 [expr {($value >> 16) & 0xFF}]
        set b2 [expr {($value >> 8) & 0xFF}]
        set b3 [expr {$value & 0xFF}]
        return "[_packByte $b0][_packByte $b1][_packByte $b2][_packByte $b3]"
    }

    proc _bytesToValue {bytes type} {
        switch -exact -- $type {
            U8 {
                binary scan $bytes c v
                return [expr {$v & 0xFF}]
            }
            I8 {
                binary scan $bytes c v
                return $v
            }
            U16 {
                binary scan $bytes cc b0 b1
                return [_u16be $b0 $b1]
            }
            I16 {
                binary scan $bytes cc b0 b1
                set v [_u16be $b0 $b1]
                if {$v >= 32768} {
                    set v [expr {$v - 65536}]
                }
                return $v
            }
            U32 {
                binary scan $bytes cccc b0 b1 b2 b3
                return [_u32be $b0 $b1 $b2 $b3]
            }
            I32 {
                binary scan $bytes cccc b0 b1 b2 b3
                set v [_u32be $b0 $b1 $b2 $b3]
                if {$v >= 2147483648} {
                    set v [expr {$v - 4294967296}]
                }
                return $v
            }
            default {
                return [binary encode hex $bytes]
            }
        }
    }

    proc _valueToBytes {value type length} {
        switch -exact -- $type {
            U8 - I8 {
                return [_packByte $value]
            }
            U16 - I16 {
                return [_packU16be $value]
            }
            U32 - I32 {
                return [_packU32be $value]
            }
            default {
                set raw [binary decode hex $value]
                return [string range "$raw[string repeat \x00 $length]" 0 [expr {$length - 1}]]
            }
        }
    }

    proc decodeParamsFromMib {paramsBytes paramDefs} {
        set decoded [dict create]
        foreach def $paramDefs {
            set name [dict get $def param_name]
            set offset [dict get $def offset]
            set length [dict get $def length]
            set type [dict get $def type]
            set end [expr {$offset + $length - 1}]
            if {$end >= [string length $paramsBytes]} {
                dict set decoded $name "<missing>"
                continue
            }
            set raw [string range $paramsBytes $offset $end]
            dict set decoded $name [_bytesToValue $raw $type]
        }
        return $decoded
    }

    proc encodeParamsFromMib {paramValues paramDefs} {
        set maxEnd -1
        foreach def $paramDefs {
            set offset [dict get $def offset]
            set length [dict get $def length]
            set end [expr {$offset + $length - 1}]
            if {$end > $maxEnd} {
                set maxEnd $end
            }
        }
        if {$maxEnd < 0} {
            return ""
        }

        set bytes [string repeat \x00 [expr {$maxEnd + 1}]]
        foreach def $paramDefs {
            set name [dict get $def param_name]
            set offset [dict get $def offset]
            set length [dict get $def length]
            set type [dict get $def type]

            if {[dict exists $paramValues $name]} {
                set value [dict get $paramValues $name]
            } else {
                set value 0
            }

            set raw [_valueToBytes $value $type $length]
            set raw [string range "$raw[string repeat \x00 $length]" 0 [expr {$length - 1}]]
            set bytes [string replace $bytes $offset [expr {$offset + $length - 1}] $raw]
        }
        return $bytes
    }

    proc decodeSpacePacket {packetBytes} {
        set n [string length $packetBytes]
        if {$n < 6} {
            error "Packet too short for CCSDS primary header"
        }

        binary scan [string range $packetBytes 0 5] cccccc b0 b1 b2 b3 b4 b5
        set first [_u16be $b0 $b1]
        set second [_u16be $b2 $b3]
        set third [_u16be $b4 $b5]
        set version [expr {($first >> 13) & 0x7}]
        set pktType [expr {($first >> 12) & 0x1}]
        set secHeader [expr {($first >> 11) & 0x1}]
        set apid [expr {$first & 0x7FF}]
        set seqFlags [expr {($second >> 14) & 0x3}]
        set seqCount [expr {$second & 0x3FFF}]
        set dataLength $third

        set expected [expr {$dataLength + 1 + 6}]
        if {$n != $expected} {
            error "CCSDS packet length mismatch expected=$expected actual=$n"
        }

        set payload [string range $packetBytes 6 end]

        return [dict create \
            version $version \
            packet_type $pktType \
            secondary_header_flag $secHeader \
            apid $apid \
            sequence_flags $seqFlags \
            sequence_count $seqCount \
            data_length $dataLength \
            payload $payload]
    }

    proc encodeSpacePacket {args} {
        array set opt {
            version 0
            packet_type 0
            secondary_header_flag 1
            apid 0
            sequence_flags 3
            sequence_count 0
            payload ""
        }
        array set opt $args

        set payloadLen [string length $opt(payload)]
        if {$payloadLen < 1} {
            error "Payload must contain at least 1 byte"
        }

        set first [expr {(($opt(version) & 0x7) << 13) | (($opt(packet_type) & 0x1) << 12) | (($opt(secondary_header_flag) & 0x1) << 11) | ($opt(apid) & 0x7FF)}]
        set second [expr {(($opt(sequence_flags) & 0x3) << 14) | ($opt(sequence_count) & 0x3FFF)}]
        set third [expr {$payloadLen - 1}]

        return "[_packU16be $first][_packU16be $second][_packU16be $third]$opt(payload)"
    }

    proc decodeTcPacket {packetBytes mibIndex} {
        set sp [decodeSpacePacket $packetBytes]
        if {[dict get $sp packet_type] != 1} {
            error "Expected TC packet_type=1"
        }

        set payload [dict get $sp payload]
        if {[string length $payload] < 4} {
            error "TC payload too short for minimal PUS secondary header"
        }

        binary scan $payload cccc pus0 serviceType subservice sourceId
        set pusVersion [expr {$pus0 & 0x0F}]
        set ackFlags [expr {($pus0 >> 4) & 0x0F}]
        set params [string range $payload 4 end]

        set key [format "%s:%s:%s" [dict get $sp apid] $serviceType $subservice]
        set commandDef {}
        set decodedValues [dict create]
        if {[dict exists $mibIndex commandByKey $key]} {
            set commandDef [dict get $mibIndex commandByKey $key]
            set commandName [dict get $commandDef command_name]
            if {[dict exists $mibIndex paramsByCommand $commandName]} {
                set defs [dict get $mibIndex paramsByCommand $commandName]
                set decodedValues [decodeParamsFromMib $params $defs]
            }
        }

        return [dict create \
            space_packet $sp \
            pus_version $pusVersion \
            ack_flags $ackFlags \
            service_type $serviceType \
            subservice $subservice \
            source_id $sourceId \
            params $params \
                decoded_values $decodedValues \
            command_key $key \
            command_def $commandDef]
    }

    proc buildStubTmFromTc {decodedTc tmServiceType tmSubservice payloadTail} {
        set apid [dict get [dict get $decodedTc space_packet] apid]
        set seq [dict get [dict get $decodedTc space_packet] sequence_count]
        set pus0 16
        set src 0
        set tmPayload [binary format cccca* $pus0 $tmServiceType $tmSubservice $src $payloadTail]
        return [encodeSpacePacket \
            packet_type 0 \
            apid $apid \
            sequence_count $seq \
            payload $tmPayload]
    }

    proc buildTmFromMib {decodedTc mibIndex tmServiceType tmSubservice tmParamValues} {
        set apid [dict get [dict get $decodedTc space_packet] apid]
        set seq [dict get [dict get $decodedTc space_packet] sequence_count]
        set key [format "%s:%s:%s" $apid $tmServiceType $tmSubservice]

        set payloadTail ""
        if {[dict exists $mibIndex tmByKey $key]} {
            set tmName [dict get [dict get $mibIndex tmByKey $key] tm_name]
            if {[dict exists $mibIndex tmParamsByName $tmName]} {
                set defs [dict get $mibIndex tmParamsByName $tmName]
                set payloadTail [encodeParamsFromMib $tmParamValues $defs]
            }
        }

        set pus0 16
        set src 0
        set tmPayload [binary format cccca* $pus0 $tmServiceType $tmSubservice $src $payloadTail]
        return [encodeSpacePacket \
            packet_type 0 \
            apid $apid \
            sequence_count $seq \
            payload $tmPayload]
    }
}

package provide egse::protocol 0.1.0

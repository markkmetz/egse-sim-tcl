namespace eval egse::log {
    variable fh ""
    variable logPath ""
    variable maxBytes 10485760
    variable maxFiles 5

    proc init {path {rotateBytes 10485760} {rotateFiles 5}} {
        variable fh
        variable logPath
        variable maxBytes
        variable maxFiles
        set logPath $path
        set maxBytes $rotateBytes
        set maxFiles $rotateFiles
        set dir [file dirname $path]
        file mkdir $dir
        _rotateIfNeeded
        set fh [open $path a]
        fconfigure $fh -buffering line -encoding utf-8
    }

    proc _rotateIfNeeded {} {
        variable logPath
        variable maxBytes
        variable maxFiles

        if {![file exists $logPath]} {
            return
        }
        if {[file size $logPath] < $maxBytes} {
            return
        }

        for {set i [expr {$maxFiles - 1}]} {$i >= 1} {incr i -1} {
            set src "$logPath.$i"
            set dst "$logPath.[expr {$i + 1}]"
            if {[file exists $src]} {
                file rename -force $src $dst
            }
        }
        file rename -force $logPath "$logPath.1"
    }

    proc closeLogger {} {
        variable fh
        if {$fh ne ""} {
            close $fh
            set fh ""
        }
    }

    proc _ts {} {
        return [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S%z}]
    }

    proc event {level msg} {
        variable fh
        if {$fh eq ""} {
            return
        }
        puts $fh "[ _ts ] level=$level event=[string map [list \n \\n \r \\r] $msg]"
        flush $fh
    }

    proc packet {direction transport endpoint rawBytes decodedMap} {
        variable fh
        if {$fh eq ""} {
            return
        }
        set hex [binary encode hex $rawBytes]
        set decoded ""
        if {[dict size $decodedMap] > 0} {
            set flat {}
            dict for {k v} $decodedMap {
                lappend flat "$k=$v"
            }
            set decoded [join $flat ,]
        }
        puts $fh "[ _ts ] dir=$direction transport=$transport endpoint=$endpoint raw_hex=$hex decoded=$decoded"
        flush $fh
    }
}

package provide egse::log 0.1.0

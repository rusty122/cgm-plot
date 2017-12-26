#!/usr/bin/env tclsh

package require Tcl
package require Tk
package require Plotchart
package require json
package require http
package require tls

set title "CGM Dashboard"
# plot dimensions
set height 500
set width 700
# y-axis
set y_description "Blood Glucose (mg/dL)"
set y_start 0
set y_end 300
set y_step 50
set y_axis [list $y_start $y_end $y_step]
# x-axis
set hours_displayed 12
set time_scale [clock add 0 $hours_displayed hours]
set x_leading_minutes 15
set x_time_format {%l:%M %p}
set x_hour_multiple 3
# high and low cutoffs
set low_cutoff 75
set high_cutoff 140

# TODO: seetup timescale dynamically
set now [clock seconds]
set stop [clock add $now $x_leading_minutes minutes]
set start [clock add $stop -$hours_displayed hours]

# time_local_hour: given a time in seconds, return the local hour as a number
proc time_local_hour {t} {
    set hour [clock format $t -format {%I}]
    scan $hour "%d" hour ;# format hour string so it gets parsed as integer
    return $hour
}

# gen_x_labels: manually pick x-axis labels from the beginning of the timeline
proc gen_x_labels {begin} {
    set x_times {}
    for {set i 0} {$i < $::hours_displayed + 1} {incr i} {
        set t [clock add $begin $i hours]
        # only use time if hour is not approprite multiple then use
        # empty string placeholder so that hourly tickmarks still render
        if {[time_local_hour $t] % $::x_hour_multiple == 0} {
            lappend x_times [clock format $t -format $::x_time_format]
        } else {
            lappend x_times " "
        }
    }
    return $x_times
}

# config: configure settings of plot
proc config {s} {
    $s dotconfig data -colour black -outline off -scalebyvalue off -radius 3
    $s dotconfig current -colour white -outline on -scalebyvalue off -radius 4
    $s vectorconfig low -colour red
    $s vectorconfig high -colour yellow
    $s balloonconfig -outline white
}

# INITIALIZE CANVAS
canvas .c -background white -width $width -height $height
pack .c -fill both

# plot_data: clear existing data and the x-axis, redraw the x-axis and plot each point
proc plot_data {start stop xlist ylist} {
    set x_axis [list $start $stop ""]
    # clear the current plot
    .c delete all
    set s [::Plotchart::createXYPlot .c $x_axis $::y_axis -xlabels [gen_x_labels $start]]
    config $s
    $s title $::title
    if {$::tcl_version < 8.6} {
        $s ytext $::y_description
    } else {
        $s vtext $::y_description
    }
    $s vector low $start $::low_cutoff $::time_scale 0
    $s vector high $start $::high_cutoff $::time_scale 0
    # TODO: find min and max values and draw balloons
    foreach x $xlist y $ylist {
        $s dot data $x $y _
    }
    return $s
}

set nightscout_url <your_nightscout_url>
set api_endpoint /api/v1/entries/sgv.json

set params [::http::formatQuery count 1000 find\[date\]\[\$gte\] 1514221161000]
# register socket for https requests
http::register https 443 [list ::tls::socket -tls1 1]
set token [::http::geturl "$nightscout_url$api_endpoint?$params"]
set data [::http::data $token]
set dictionary [::json::json2dict $data]
set x_list {}
set y_list {}
foreach doc $dictionary {
    lappend y_list [dict get $doc sgv]
    lappend x_list [expr {[dict get $doc date] / 1000}]
}
puts $x_list
puts $y_list
plot_data $start $stop $x_list $y_list

#!/usr/bin/tclsh

package require Tcl
package require Tk
package require Plotchart

# constants for plot dimensions
set height 500
set width 700

# constants for y-axis
set y_description "Blood Glucose (mg/dL)"
set y_start 0
set y_end 300
set y_step 50

# constants for x-axis
set hours_displayed 6
set time_scale [clock add 0 $hours_displayed hours]
set x_leading_minutes 15
set x_time_format {%l:%M %p}
set x_hour_multiple 3

# constants for low and high cutoffs
set low_cutoff 75
set high_cutoff 140

# setup timescale
set now [clock seconds]
set stop [clock add $now $x_leading_minutes minutes]
set start [clock add $stop -$hours_displayed hours]

proc time_local_hour {t} {
    set hour [clock format $t -format {%I}]
    # format hour string so it gets parsed as integer
    scan $hour "%d" hour
    return $hour
}

# manually pick x-axis labels
set x_times {}
for {set i 0} {$i < $hours_displayed + 1} {incr i} {
    set t [clock add $start $i hours]
    # only use time if hour is not approprite multiple then use
    # empty string placeholder so that hourly tickmarks still render
    if {[time_local_hour $t] % $x_hour_multiple == 0} {
        lappend x_times [clock format $t -format $x_time_format]
    } else {
        lappend x_times " "
    }
}

# create canvas and initialize plot
canvas .c -background white -width $width -height $height
pack .c -fill both
set s [::Plotchart::createXYPlot .c [list $start $stop ""] [list $y_start $y_end $y_step] -xlabels $x_times]

# perform configuration
$s dotconfig data -colour black -outline off -scalebyvalue off -radius 3.5
$s dotconfig current -colour white -outline on -scalebyvalue off -radius 4
$s vectorconfig low -colour red
$s vectorconfig high -colour yellow
$s balloonconfig -outline white

# draw high and low vectors
$s vector low $start $low_cutoff $time_scale 0
$s vector high $start $high_cutoff $time_scale 0

# Set chart title and axis labels
$s title "CGM Dashboard"
if {$tcl_version < 8.6} {
    $s ytext $y_description
} else {
    $s vtext $y_description
}

# bogus data
$s dot data $now 140 _
$s dot current $now 120 _
$s dot data $now 50 _

$s balloon $now 145 "Max: 140" south
$s balloon $now 45 "Min: 50" north

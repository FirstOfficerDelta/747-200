# put all code in comment to recover the default behaviour.


# ========================
# OVERRIDING NASAL GLOBALS
# ========================


# override flaps controls, to trigger the leading edge flaps
override_flapsDown = controls.flapsDown;

controls.flapsDown = func( step ) {
   var flapspos = constant.nonil( getprop("/controls/flight/flaps") );

   # only flaps 1 and 5 deg
   if( flapspos < getprop("/sim/flaps/setting[3]") ) {
       # uses slats interface
       controls.stepSlats( step );

       # no FG interface with JSBSim
       setprop( "/fdm/jsbsim/fcs/LE-flap-cmd-norm", getprop("/controls/flight/slats") );
   }

   override_flapsDown( step );
}


# 2018.2 introduces new "all" properties for throttle, mixture and prop pitch.
# this is the correct way to interface with the axis based controls - use a listener
# on the *-all property

_setlistener("/controls/engines/throttle-all", func{
    var position = (1 - getprop("/controls/engines/throttle-all")) / 2;

    # autothrottle doesn't move throttle
    props.setAll("/controls/engines/engine", "throttle", position);

    props.setAll("/controls/engines/engine", "throttle-manual", position);
},0,0);
# overrides the joystick axis handler to make inert the throttle animation with autothrottle
override_throttleAxis = controls.throttleAxis;

# backwards compatibility only - the controls.throttleAxis should not be overridden like this. The joystick binding Throttle (all) has 
# been replaced and controls.throttleAxis will not be called from the controls binding
controls.throttleAxis = func {
    var val = cmdarg().getNode("setting").getValue();
    if(size(arg) > 0) { val = -val; }

    var position = (1 - val)/2;

    # autothrottle doesn't move throttle
    props.setAll("/controls/engines/engine", "throttle", position);

    props.setAll("/controls/engines/engine", "throttle-manual", position);
}


# overrides keyboard for autopilot adjustment.

override_incElevator = controls.incElevator;

controls.incElevator = func {
    var sign = 1.0;
    
    if( arg[0] < 0.0 ) {
	sign = -1.0;
    }
    
    if( !globals.Boeing747.autopilotsystem.adjustexport(1.0 * sign) ) {
        # default
        override_incElevator(arg[0], arg[1]);
    }
}

override_incAileron = controls.incAileron;

controls.incAileron = func {
    var sign = 1.0;
    
    if( arg[0] < 0.0 ) {
	sign = -1.0;
    }
    
    if( !globals.Boeing747.autopilotsystem.headingknobexport(1.0 * sign) ) {
        # default
        override_incAileron(arg[0], arg[1]);
    }
}

override_incThrottle = controls.incThrottle;

controls.incThrottle = func {
    var sign = 1.0;
    
    if( arg[0] < 0.0 ) {
	sign = -1.0;
    }
    
    if( !globals.Boeing747.autothrottlesystem.speedknobexport(1.0 * sign) ) {
        # default
        override_incThrottle(arg[0], arg[1]);
    }
}

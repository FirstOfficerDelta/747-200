# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =========
# AUTOPILOT
# =========

Autopilot = {};

Autopilot.new = func {
   var obj = { parents : [Autopilot,System.new("/systems/autopilot")],

               autothrottlesystem : nil,

               PREDICTIONSEC : 6.0,
               STABLESEC : 3.0,
               AUTOPILOTSEC : 3.0,                            # refresh rate
               AUTOLANDSEC : 1.0,
               SAFESEC : 1.0,
               TOUCHSEC : 0.2,
               FLARESEC : 0.1,
       
               timerautoland : nil,

               LANDINGLB : 630000.0,                          # max landing weight
               EMPTYLB : 376170.0,                            # empty weight

               TOUCHFULLDEG : 3.0,                            # landing pitch
               TOUCHEMPTYDEG : 1.75,
# for smooth transition, lightly above approach pitch
               FLAREFULLDEG : 2.0,                            # avoids rebound by landing pitch
               FLAREEMPTYDEG : 1.5,

               AUTOLANDFEET : 1500.0,
# instead of 100 ft, as catching glide makes nose down
# (bug in glide slope, or more sophisticated autopilot is required ?)
               GLIDEFEET : 250.0,                             # leaves glide slope
# nav is supposed accurate until 0 ft.
# bypass possible nav errors (example : EGLL 27R).
               NAVFEET : 200.0,                               # leaves nav
# a responsive vertical-speed-with-throttle reduces the rebound by ground effect
               GROUNDFEET : 20.0,                             # altimeter altitude

               CRUISEKT : 450.0,
               TRANSITIONKT : 250.0,
               VREFFULLKT : 154.0,
               VREFEMPTYKT : 120.0,

               TOUCHFPM : -750.0,                             # structural limit
 
               landheadingdeg : 0.0,                          # touch down without nav
 
               BANKTRACKDEG : 7.0,                            # track error for clamping bank angle
               BANKMAGDEG : 5.0,                              # magnetic error for clamping bank angle
               BANKNAVDEG : 5.0,                              # nav error for clamping bank angle
               ROLLDEG : 2.0,                                 # roll to swap to next waypoint

               BANKMAX : 1.0,
               BANKCLAMP : 0.1667,
           
               routeactive : constant.FALSE,

               WPTNM : 3.0,                                   # distance to swap to next waypoint
               VORNM : 3.0                                    # distance to inhibate VOR
         };

   obj.init();

   return obj;
};

Autopilot.init = func {
   me.timerautoland = maketimer(me.AUTOLANDSEC, me, me.autoland);
   me.timerautoland.simulatedTime = 1;
   me.timerautoland.singleShot = 1;

   # selectors
   me.aphorizontalexport();
}

Autopilot.set_relation = func( autothrottle ) {
   me.autothrottlesystem = autothrottle;
}

Autopilot.adjustexport = func( sign ) {
   var result = constant.FALSE;

   if( me.has_lock_altitude() ) {
       var value = 0.0;

       result = constant.TRUE;

       # 10 or 100 ft/min per key
       if( me.is_lock_vertical() ) {
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 100.0 * sign;
           }
           else {
               value = 100.0 * sign;
           }
       }
       # 10 or 100 ft per key
       elsif( me.is_lock_altitude() ) {
           if( sign >= -0.1 and sign <= 0.1 ) {
               value = 100.0 * sign;
           }
           else {
               value = 100.0 * sign;
           }
       }
       # default (touches cursor)
       else {
           value = 0.0;
       }

       if( me.is_lock_vertical() ) {
           var targetfpm = me.itself["settings"].getChild("vertical-speed-fpm").getValue();

           if( targetfpm == nil ) {
               targetfpm = 0.0;
           }
           
           targetfpm = targetfpm + value;
           me.itself["settings"].getChild("vertical-speed-fpm").setValue(targetfpm);
       }
       elsif( me.is_lock_altitude() ) {
           var targetft = me.itself["autoflight"].getChild("dial-altitude-ft").getValue();

           targetft = targetft + value;
           me.itself["autoflight"].getChild("dial-altitude-ft").setValue(targetft);
           me.itself["settings"].getChild("target-altitude-ft").setValue(targetft);
       }
   }

   return result;
}

# manual setting of heading with knob
Autopilot.headingknobexport = func( sign ) {
   var result = constant.FALSE;

   if( me.has_lock_heading() ) {
       var headingdeg = 0.0;

       result = constant.TRUE;

       if( me.is_lock_magnetic() ) {
           headingdeg = me.itself["autoflight"].getChild("dial-heading-deg").getValue();
           
           headingdeg = headingdeg + sign;
           headingdeg = geo.normdeg( headingdeg );
           
           me.itself["autoflight"].getChild("dial-heading-deg").setValue(headingdeg);
           me.itself["settings"].getChild("heading-bug-deg").setValue(headingdeg);
       }
   }

   return result;
}

Autopilot.schedule = func {
   var activation = constant.FALSE;
   var id = ["", "", ""];


   # TEMPORARY work around for 2.0.0
   if( me.route_active() ) {
       activation = constant.TRUE;

       # each time, because the route can change
       var wp = me.itself["route"].getChildren("wp");
       var current_wp = me.itself["route-manager"].getChild("current-wp").getValue();
       var nb_wp = size(wp);

       # route manager doesn't update these fields
       if( nb_wp >= 1 and current_wp < nb_wp ) {
           id[0] = wp[current_wp].getChild("id").getValue();

           # defaut
           id[1] = "";
           id[2] = id[0];
       }

       if( nb_wp >= 2 and (current_wp + 1) < nb_wp ) {
           id[1] = wp[current_wp + 1].getChild("id").getValue();
       }

       if( nb_wp > 0 ) {
           id[2] = wp[nb_wp-1].getChild("id").getValue();
       }
   }

   me.itself["waypoint"][0].getChild("id").setValue( id[0] );
   me.itself["waypoint"][1].getChild("id").setValue( id[1] );
   me.itself["route-manager"].getNode("wp-last").getNode("id",constant.DELAYEDNODE).setValue( id[2] );


   # user adds a waypoint
   if( me.is_waypoint() ) {
       # real behaviour : INS input doesn't toggle autopilot
       if( !me.itself["autoflight"].getChild("fg-waypoint").getValue() ) {
           # keep current heading mode, if any
           if( !me.is_lock_true() ) {
               me.aphorizontalexport();
           }

           # already in true heading mode : keep display coherent
           elsif( !me.is_ins() ) {
               me.aptoggleinsexport();
           }
       }

       # Feedback requested by user : activation of route toggles autopilot
       elsif( !me.routeactive ) {
           # only when route is being activated (otherwise cannot leave INS mode)
           if( !me.is_ins() ) {
               me.aptoggleinsexport();
           }
       }
   }


   if( me.is_engaged() ) {
       # avoids strong bank
       if( me.is_ins() ) {
           me.waypointroll();
       }
       elsif( me.is_vor() ) {
           me.vorroll();
       }

       # heading changed by keyboard
       elsif( me.is_magnetic() ) {
           var dialdeg = me.itself["autoflight"].getChild("dial-heading-deg").getValue();
           var headingdeg = me.itself["settings"].getChild("heading-bug-deg").getValue();
           if( headingdeg != dialdeg ) {
               me.itself["autoflight"].getChild("dial-heading-deg").setValue(headingdeg);
           }
       }
   }


   # more sensitive at supersonic speed
   me.sonicheadingmode();


   me.routeactive = activation;
}

# avoid strong roll near a waypoint
Autopilot.waypointroll = func {
    var distancenm = me.itself["waypoint"][0].getChild("dist").getValue();

    # next waypoint
    if( distancenm != nil ) {
        var lastnm = me.itself["state"].getChild("waypoint-nm").getValue();

        # avoids strong roll
        if( distancenm < me.WPTNM ) {
            var rolldeg =  me.noinstrument["roll"].getValue();

            # switches to heading hold
            if( distancenm > lastnm or math.abs(rolldeg) > me.ROLLDEG ) {
                if( me.is_lock_true() ) {
                    me.itself["route-manager"].getChild("input").setValue("@DELETE0");
                }
            }
        }

        me.itself["state"].getChild("waypoint-nm").setValue(distancenm);
    }
}

# avoid strong roll near a VOR
Autopilot.vorroll = func {
    # near VOR
    if( me.dependency["dme"].getChild("in-range").getValue() ) {
        # restores after VOR
        if( me.dependency["dme"].getChild("indicated-distance-nm").getValue() > me.VORNM ) {
            if( me.is_lock_magnetic() ) {
                me.locknav1();
            }

            me.itself["state"].getChild("vor-engage").setValue(constant.FALSE);
        }

        # avoids strong roll
        else {
            # switches to heading hold
            if( me.is_lock_nav1() ) {
                # except if mode has just been engaged, leaving a VOR :
                # EGLL 27R, then leaving LONDON VOR 113.60 on its 260 deg radial (SID COMPTON 3).
                if( !me.itself["state"].getChild("vor-engage").getValue() or
                    ( me.itself["state"].getChild("vor-engage").getValue() and
                      me.dependency["nav"].getChild("from-flag").getValue() ) ) { 
                    me.holdmagnetic();
                }
            }
        }
    }
}

Autopilot.clampweight = func ( vallanding, valempty ) {
    var result = 0.0;

    var weightlb = me.noinstrument["weight"].getValue();
    if( weightlb > me.LANDINGLB ) {
        result = vallanding;
    }
    else {
        var coef = ( me.LANDINGLB - weightlb ) / ( me.LANDINGLB - me.EMPTYLB );

        result = vallanding + coef * ( valempty - vallanding );
    }

    return result;
}

Autopilot.is_engaged = func {
   var result = constant.FALSE;

   if( me.itself["channel"][0].getChild("engage").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.engage = func( state ) {
   me.itself["channel"][0].getChild("engage").setValue( state );
}

Autopilot.apdisableexport = func {
   me.apdisable();

   me.apengageexport();
}

Autopilot.apdisable = func {
   me.engage(constant.FALSE);

   me.itself["autoflight"].getChild("heading").setValue("");
   me.itself["autoflight"].getChild("altitude").setValue("");
   me.itself["autoflight"].getChild("vertical").setValue("");

   me.itself["locks"].getChild("heading").setValue("");
   me.itself["locks"].getChild("altitude").setValue("");
}

Autopilot.disabledexport = func {
}

Autopilot.apengageexport = func {
   var altitudemode = "";
   var headingmode = "";

   if( me.is_engaged() ) {
       var verticalmode = me.itself["autoflight"].getChild("vertical").getValue();

       altitudemode = me.itself["autoflight"].getChild("altitude").getValue();
       headingmode = me.itself["autoflight"].getChild("heading").getValue();

       if( me.is_altitude_select() ) {
           altitudemode = "altitude-hold";
       }

       # vertical speed has priority on altitude hold
       if( verticalmode != "" ) {
           altitudemode = verticalmode;
       }

       # approach has priority
       if( me.is_ils() or me.is_autoland() ) {
           headingmode = "nav1-hold";
           altitudemode = "gs1-hold";
       }
   }

   me.itself["locks"].getChild("altitude").setValue(altitudemode);
   me.itself["locks"].getChild("heading").setValue(headingmode);

   if( me.is_magnetic() ) {
       var headingdeg = me.itself["autoflight"].getChild("dial-heading-deg").getValue();

       me.itself["settings"].getChild("heading-bug-deg").setValue(headingdeg);
   }

   me.autoland();
}


# ---------------
# HORIZONTAL MODE
# ---------------

Autopilot.is_waypoint = func {
   var result = constant.FALSE;

   if( me.route_active() ) {
       var id = me.itself["waypoint"][0].getChild("id").getValue();
       if( id != nil and id != "" ) {
           result = constant.TRUE;
       }
   }

   return result;
}

Autopilot.route_active = func {
   var result = constant.FALSE;

   # autopilot/route-manager/wp is updated only once airborne
   if( me.itself["route-manager"].getChild("active").getValue() and
       me.itself["route-manager"].getChild("airborne").getValue() ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_nav1 = func {
   var result = constant.FALSE;
   var headingmode = me.itself["autoflight"].getChild("heading").getValue();

   if( headingmode == "nav1-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_lock_nav1 = func {
   var result = constant.FALSE;
   var headingmode = me.itself["locks"].getChild("heading").getValue();

   if( headingmode == "nav1-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.locknav1 = func {
   me.itself["locks"].getChild("heading").setValue("nav1-hold");
}

# toggle vor loc (ctrl-N)
Autopilot.aptogglevorlocexport = func {
   if( !me.is_nav1() or ( me.is_nav1() and !me.is_engaged() ) ) {
       me.engage(constant.TRUE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(0);
   }
   else {
       me.engage(constant.FALSE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(-1);
   }

   me.aphorizontalexport();
}

Autopilot.is_ins = func {
   var result = constant.FALSE;

   var horizontalselector = me.itself["autoflight"].getChild("horizontal-selector").getValue();

   if( horizontalselector == -2 ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.aptoggleinsexport = func {
   if( !me.is_ins() or ( me.is_ins() and !me.is_engaged() ) ) {
       me.engage(constant.TRUE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(-2);
   }
   else {
       me.engage(constant.FALSE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(-1);
   }

   me.aphorizontalexport();
}

Autopilot.is_vor = func {
   var result= constant.FALSE;

   var horizontalselector = me.itself["autoflight"].getChild("horizontal-selector").getValue();

   if( horizontalselector == 0 ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.aphorizontalexport = func {
   var headingmode = "";

   var horizontalselector = me.itself["autoflight"].getChild("horizontal-selector").getValue();

   if( horizontalselector == -2 ) {
       headingmode = "true-heading-hold";
   }
   elsif( horizontalselector == -1 ) {
       headingmode = "dg-heading-hold";
   }
   elsif( horizontalselector == 0 ) {
       headingmode = "nav1-hold";
   }
   elsif( horizontalselector == 1 ) {
       headingmode = "ils-hold";
   }
   elsif( horizontalselector == 2 ) {
       headingmode = "autoland-armed";
   }

   me.itself["autoflight"].getChild("heading").setValue(headingmode);

   me.apengageexport();
}

Autopilot.has_lock_heading = func {
   var result= constant.FALSE;

   var headingmode = me.itself["locks"].getChild("heading").getValue();

   if( headingmode != "" and headingmode != nil ) {
       result = constant.TRUE;
   }

   return result;
}


# ------------
# HEADING MODE
# ------------

Autopilot.bankprediction = func( name, mindeg ) {
   var factor = me.BANKMAX;
   
   # disabled, when it amplifies oscillations (speed up).
   if( !me.itself["pid"].getChild("bank-prediction").getValue() or
       me.noinstrument["speed-up"].getValue() > 1.0 ) {
   }


   else {
       var errordeg = 0.0;
       var offsetdeg = 0.0;

       errordeg = me.itself["pid"].getNode(name).getChild("input").getValue();

       offsetdeg = math.abs( errordeg );
       
       if( offsetdeg < mindeg ) {
           # clamping
           factor = me.BANKCLAMP;
       }
   }
   
   return factor;
}

Autopilot.is_lock_true = func {
   var result = constant.FALSE;

   var headingmode = me.itself["locks"].getChild("heading").getValue();

   if( headingmode == "true-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_magnetic = func {
   var result = constant.FALSE;

   var headingmode = me.itself["autoflight"].getChild("heading").getValue();

   if( headingmode == "dg-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_lock_magnetic = func {
   var result = constant.FALSE;

   var headingmode = me.itself["locks"].getChild("heading").getValue();

   if( headingmode == "dg-heading-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.locktrue = func {
   me.itself["locks"].getChild("heading").setValue("true-heading-hold");
}

Autopilot.lockmagnetic = func {
   me.itself["locks"].getChild("heading").setValue("dg-heading-hold");
}

Autopilot.holdmagnetic = func {
   var headingdeg = me.noinstrument["heading"].getValue();

   me.holdheading( headingdeg );
}

Autopilot.holdheading = func( headingdeg ) {
   me.itself["settings"].getChild("heading-bug-deg").setValue(headingdeg);
   me.lockmagnetic();
}

# toggle heading hold (ctrl-H)
Autopilot.aptoggleheadingexport = func {
   if( !me.is_magnetic() or ( me.is_magnetic() and !me.is_engaged() ) ) {
       me.engage(constant.TRUE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(-1);
   }
   else {
       me.engage(constant.FALSE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(-1);
   }

   me.aphorizontalexport();
}

Autopilot.sonicheadingmode = func {
   if( me.is_lock_magnetic() ) {
       me.sonicmagneticheading();
   }

   elsif( me.is_lock_true() ) {
       me.sonictrueheading();
   }

   elsif( me.is_lock_nav1() ) {
       me.sonicnavheading();
   }
}

# sonic true mode
Autopilot.sonictrueheading = func {
   var name = "true-heading-hold1";
   var node = me.itself["pid"].getNode(name);
   var factor = me.bankprediction( name, me.BANKTRACKDEG );

   node.getChild("u_min").setValue( me.itself["config"].getNode(name).getChild("u_min").getValue() * factor );
   node.getChild("u_max").setValue( me.itself["config"].getNode(name).getChild("u_max").getValue() * factor );
}

# sonic magnetic mode
Autopilot.sonicmagneticheading = func {
   var name = "dg-heading-hold1";
   var node = me.itself["pid"].getNode(name);
   var factor = 0.0;

   if( me.is_autoland() ) {
       factor = me.BANKMAX;
   }

   else {
       factor = me.bankprediction( name, me.BANKMAGDEG );
   }

   node.getChild("u_min").setValue( me.itself["config"].getNode(name).getChild("u_min").getValue() * factor );
   node.getChild("u_max").setValue( me.itself["config"].getNode(name).getChild("u_max").getValue() * factor );
}

# sonic nav mode
Autopilot.sonicnavheading = func {
   var name = "nav-hold1";
   var node = me.itself["pid"].getNode(name);
   var factor = 0.0;

   if( me.is_autoland() ) {
       factor = me.BANKMAX;
   }

   else {
       factor = me.bankprediction( name, me.BANKNAVDEG );
   }

   node.getChild("u_min").setValue( me.itself["config"].getNode(name).getChild("u_min").getValue() * factor );
   node.getChild("u_max").setValue( me.itself["config"].getNode(name).getChild("u_max").getValue() * factor );
}


# -------------
# VERTICAL MODE
# -------------

# adjust target speed with wind
Autopilot.targetwind = func {
   # VREF
   var targetkt = me.clampweight( me.VREFFULLKT, me.VREFEMPTYKT );

   # wind increases lift
   var windkt = me.noinstrument["wind"].getChild("wind-speed-kt").getValue();
   if( windkt > 0 ) {
       var winddeg = me.noinstrument["wind"].getChild("wind-from-heading-deg").getValue();
       var vordeg = me.dependency["nav"].getNode("radials").getChild("target-radial-deg").getValue();
       var offsetdeg = vordeg - winddeg;

       offsetdeg = geo.normdeg180( offsetdeg );

       # add head wind component; except tail wind (too much glide)
       if( offsetdeg > -constant.DEG90 and offsetdeg < constant.DEG90 ) {
           var offsetrad = offsetdeg * D2R;
           var offsetkt = windkt * math.cos( offsetrad );

           # otherwise, VREF 154 kt + 30 kt head wind overspeeds the 180 kt of 30 deg flaps.
           offsetkt = offsetkt / 2;          
           if( offsetkt > 20 ) {
               offsetkt = 20;
           }
           elsif( offsetkt < 5 ) {
               offsetkt = 5;
           }

           targetkt = targetkt + offsetkt;
       }
   }

   # avoid infinite gliding
   me.itself["settings"].getChild("target-speed-kt").setValue(targetkt);
}

# reduces the rebound caused by ground effect
Autopilot.targetpitch = func( aglft ) {
   var targetdeg = 0.0;

   # counter the rebound of ground effect
   if( aglft > me.GLIDEFEET ) {
       targetdeg = me.clampweight( me.FLAREFULLDEG, me.FLAREEMPTYDEG );
   }
   elsif( aglft < me.GROUNDFEET ) {
       targetdeg = me.clampweight( me.TOUCHFULLDEG, me.TOUCHEMPTYDEG );
   }
   else {
       var coef = ( aglft - me.GROUNDFEET ) / ( me.GLIDEFEET - me.GROUNDFEET );

       var flareweightdeg = me.clampweight( me.FLAREFULLDEG, me.FLAREEMPTYDEG );
       var touchweightdeg = me.clampweight( me.TOUCHFULLDEG, me.TOUCHEMPTYDEG );

       targetdeg = touchweightdeg + coef * ( flareweightdeg - touchweightdeg );
   }
   
   me.holdpitch(targetdeg);
}

Autopilot.is_landing = func {
   var result = constant.FALSE;

   var verticalmode = me.itself["autoflight"].getChild("heading").getValue();

   if( verticalmode == "autoland" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_land_armed = func {
   var result = constant.FALSE;

   var verticalmode = me.itself["autoflight"].getChild("heading").getValue();

   if( verticalmode == "autoland-armed" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_autoland = func {
   var result = constant.FALSE;

   if( me.is_landing() or me.is_land_armed() ) {
       result = constant.TRUE;
   }

   return result;
}

# autoland mode
Autopilot.autoland = func {
   if( me.is_engaged() ) {
       if( me.is_autoland() ) {
           var rates = me.AUTOLANDSEC;
           var aglft = me.dependency["radio-altimeter"].getChild("indicated-altitude-ft").getValue();

           # armed
           if( me.is_land_armed() ) {
               if( aglft <= me.AUTOLANDFEET ) {
                   me.itself["autoflight"].getChild("heading").setValue("autoland");
               }
           }

           # engaged
           if( me.is_landing() ) {
               # touch down
               if( aglft < constantaero.AGLTOUCHFT ) {

                   # gently reduce pitch
                   if( me.noinstrument["pitch"].getValue() > 1.0 ) {
                       rates = me.TOUCHSEC;

                       # 1 deg / s
                       var pitchdeg = me.itself["settings"].getChild("target-pitch-deg").getValue();

                       pitchdeg = pitchdeg - 0.2;
                       me.holdpitch( pitchdeg );
                   }

                   # safe on ground
                   else {
                       rates = me.SAFESEC;

                       # disable autopilot and autothrottle
                       me.autothrottlesystem.atdisable();
                       me.apdisable();

                       # reset trims
                       me.dependency["flight"].getChild("elevator-trim").setValue(0.0);
                       me.dependency["flight"].getChild("rudder-trim").setValue(0.0);
                       me.dependency["flight"].getChild("aileron-trim").setValue(0.0);
                   }

                   # engine idles
                   me.autothrottlesystem.idle();
               }

               # triggers below 1500 ft
               elsif( aglft > me.AUTOLANDFEET ) {
                   me.itself["autoflight"].getChild("heading").setValue("autoland-armed");
               }

               # systematic forcing of speed modes
               else {
                   if( aglft < me.GLIDEFEET ) {
                       rates = me.FLARESEC;

                       # landing pitch (flare) : removes the rebound at touch down of vertical-speed-hold.
                       me.targetpitch( aglft );

                       # heading hold avoids roll outside the runway.
                       if( !me.itself["autoflight"].getChild("real-nav").getValue() ) {
                           if( aglft < me.NAVFEET ) {
                               if( !me.is_lock_magnetic() ) {
                                   me.landheadingdeg = me.noinstrument["heading"].getValue();
                               }
                               me.holdheading( me.landheadingdeg );
                           }
                       }

                       # pilot must activate autothrottle
                       me.itself["settings"].getChild("vertical-speed-fpm").setValue( me.TOUCHFPM );
                       me.autothrottlesystem.atenable("vertical-speed-with-throttle");

                   }

                   # glide slope : cannot go back when then aircraft climbs again (caused by landing pitch),
                   # otherwise will crash to catch the glide slope.
                   elsif( !me.autothrottlesystem.is_glide() ) {
                       # near VREF (no wind)
                       me.targetwind();

                       # pilot must activate autothrottle
                       me.autothrottlesystem.atsend();
                   }

                   # records attitude at flare
                   else {
                       me.FLAREDEG = me.noinstrument["pitch"].getValue();
                   }
               } 
           }
       }

       # re-schedule the next call
       if( me.is_autoland() ) {
           me.timerautoland.restart(rates);
       }
       else {
           me.timerautoland.stop();
       }
   }
}

Autopilot.is_ils = func {
   var result = constant.FALSE;

   var headingmode = me.itself["autoflight"].getChild("heading").getValue();

   if( headingmode == "ils-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

# toggle glide slope (ctrl-G)
Autopilot.aptoggleglideexport = func {
   if( !me.is_ils() or ( me.is_ils() and !me.is_engaged() ) ) {
       me.engage(constant.TRUE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(1);
   }
   else {
       me.engage(constant.FALSE);
       me.itself["autoflight"].getChild("horizontal-selector").setValue(-1);
   }

   me.aphorizontalexport();
}

Autopilot.has_lock_altitude = func {
   var result= constant.FALSE;

   var altitudemode = me.itself["locks"].getChild("altitude").getValue();

   if( altitudemode != "" and altitudemode != nil ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.is_lock_vertical = func {
   var result = constant.FALSE;

   var altitudemode = me.itself["locks"].getChild("altitude").getValue();

   if( altitudemode == "vertical-speed-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

Autopilot.apverticalexport = func {
   var verticalmode = "";

   var verticalselector = me.itself["autoflight"].getChild("vertical-selector").getValue();

   if( verticalselector == -1 ) {
       verticalmode = "";
   }
   elsif( verticalselector == 0 ) {
       verticalmode = "vertical-speed-hold";

       var verticalspeedfps = me.dependency["ivsi"].getChild("indicated-speed-fps").getValue();
       var verticalspeedfpm = verticalspeedfps * constant.MINUTETOSECOND;

       me.itself["settings"].getChild("vertical-speed-fpm").setValue(verticalspeedfpm);
   }

   me.itself["autoflight"].getChild("vertical").setValue(verticalmode);

   me.apengageexport();
}

Autopilot.holdpitch = func( pitchdeg ) {
   me.itself["settings"].getNode("target-pitch-deg").setValue(pitchdeg);
   me.lockpitch();
}

Autopilot.lockpitch = func {
   me.itself["locks"].getChild("altitude").setValue("pitch-hold");
}


# -------------
# ALTITUDE MODE
# -------------

Autopilot.is_altitude_select = func {
   var result = constant.FALSE;

   var altitudemode = me.itself["autoflight"].getChild("altitude").getValue();

   if( altitudemode == "altitude-select" ) {
       result = constant.TRUE;
   }

   return result;
}

# toggle altitude select (ctrl-A)
Autopilot.aptogglealtitudeexport = func {
   if( !me.is_altitude_select() ) {
       me.engage(constant.TRUE);
       me.apaltitudeselectexport();
   }
   else {
       me.itself["autoflight"].getChild("altitude").setValue("");

       me.apverticalexport();
   }
}

Autopilot.apaltitudeselectexport = func {
   var targetft = me.itself["autoflight"].getChild("dial-altitude-ft").getValue();

   me.itself["settings"].getChild("target-altitude-ft").setValue(targetft);
   me.itself["autoflight"].getChild("altitude").setValue("altitude-select");

   me.apengageexport();
}

Autopilot.is_altitude_hold = func {
   var result = constant.FALSE;

   var altitudemode = me.itself["autoflight"].getChild("altitude").getValue();

   if( altitudemode == "altitude-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

# toggle altitude hold (ctrl-T)
Autopilot.aptogglealtitudeholdexport = func {
   if( !me.is_altitude_hold() ) {
       me.engage(constant.TRUE);
       me.apaltitudeholdexport();
   }
   else {
       me.itself["autoflight"].getChild("altitude").setValue("");

       me.apverticalexport();
   }
}

Autopilot.apaltitudeholdexport = func {
   var targetft = me.dependency["altimeter"].getChild("indicated-altitude-ft").getValue();

   me.itself["settings"].getChild("target-altitude-ft").setValue(targetft);
   me.itself["autoflight"].getChild("altitude").setValue("altitude-hold");

   me.apengageexport();
}

Autopilot.is_lock_altitude = func {
   var result = constant.FALSE;

   var altitudemode = me.itself["locks"].getChild("altitude").getValue();

   if( altitudemode == "altitude-hold" ) {
       result = constant.TRUE;
   }

   return result;
}

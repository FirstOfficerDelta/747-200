# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron
# HUMAN : functions ending by human are called by artificial intelligence



# This file contains checklist tasks.


# ================
# VIRTUAL ENGINEER
# ================

Virtualengineer = {};

Virtualengineer.new = func {
   var obj = { parents : [Virtualengineer], 

               navigation : Navigation.new()
         };

    obj.init();

    return obj;
}

Virtualengineer.init = func {
}

Virtualengineer.veryslowschedule = func {
    me.navigation.schedule();
}


# ==========
# NAVIGATION
# ==========

Navigation = {};

Navigation.new = func {
   var obj = { parents : [Navigation,System.new("/systems/engineer")], 
   
               launchhour : 0,
               launchminute : 0,
               launchsecond : 0,

               altitudeft : 0.0,

               last : constant.FALSE,

               NOSPEEDFPM : 0.0,

               SUBSONICKT : 480,                                 # estimated ground speed
               FLIGHTKT : 150,                                   # minimum ground speed

               groundkt : 0,

               SUBSONICKGPH : 20000,                             # subsonic consumption

               galusph : 0,

               NOFUELGALUS : -999,

               totalgalus : 0
         };

   obj.init();

   return obj;
}

Navigation.init = func {
   me.launchhour = me.noinstrument["time-real"].getChild("hour").getValue();
   me.launchminute = me.noinstrument["time-real"].getChild("minute").getValue();
   me.launchsecond = me.noinstrument["time-real"].getChild("second").getValue();
}

Navigation.schedule = func {
   me.waypoints();
   me.time();
   me.time_real();
}

Navigation.time = func {
   var elapsedsec = me.dependency["time"].getValue();
    
   var elapsedhours = me.second_to_hour( elapsedsec );
   me.itself["root"].getNode("navigation").getChild("elapsed-hours").setValue(elapsedhours);
}

Navigation.time_real = func {
   var nowhour = me.noinstrument["time-real"].getChild("hour").getValue();
   var nowminute = me.noinstrument["time-real"].getChild("minute").getValue();
   var nowsecond = me.noinstrument["time-real"].getChild("second").getValue();
   
   var elapsedsec = 0;
   
   # change of day
   if( nowhour < me.launchhour ) {
       elapsedsec = (constant.HOURLAST - me.launchhour) * constant.HOURTOSECOND + elapsedsec;
       elapsedsec = (constant.MINUTELAST - me.launchminute) * constant.MINUTETOSECOND + elapsedsec;
       elapsedsec = (constant.SECONDLAST - me.launchsecond) + elapsedsec;

       elapsedsec = nowhour * constant.HOURTOSECOND + elapsedsec;
       elapsedsec = nowminute * constant.MINUTETOSECOND + elapsedsec;
       elapsedsec = nowsecond + elapsedsec;
   }
   else {
       elapsedsec = (nowhour - me.launchhour) * constant.HOURTOSECOND + elapsedsec;
       elapsedsec = (nowminute - me.launchminute) * constant.MINUTETOSECOND + elapsedsec;
       elapsedsec = (nowsecond - me.launchsecond) + elapsedsec;
   }

   var clockstring = me.second_to_time( elapsedsec );
   me.itself["root"].getNode("navigation").getChild("clock-string").setValue(clockstring);
}

Navigation.second_to_hour = func( elapsedsec ) {
   var elapsedhours = elapsedsec / constant.HOURTOSECOND;
   
   elapsedhours = math.round( elapsedhours * 10 ) / 10;
   
   return elapsedhours;
}

Navigation.second_to_time = func( elapsedsec ) {
   var clockhours = int( elapsedsec / constant.HOURTOSECOND );

   var clockminutes = int( (elapsedsec - clockhours * constant.HOURTOSECOND) / constant.MINUTETOSECOND );

   var clockseconds = elapsedsec - clockhours * constant.HOURTOSECOND -  clockminutes * constant.MINUTETOSECOND;
   
   clockstring = sprintf("%02d",clockhours) ~ ":" ~ sprintf("%02d",clockminutes) ~ ":" ~ sprintf("%02d",clockseconds);
   
   return clockstring;
}

Navigation.waypoints = func {
   var groundfps = me.dependency["ins"].getNode("computed/ground-speed-fps").getValue();
   var id = "";
   var distnm = 0.0;
   var targetft = 0;
   var selectft = 0.0;
   var fuelgalus = 0.0;
   var speedfpm = 0.0;
   var child = nil;

   if( groundfps != nil ) {
       me.groundkt = groundfps * FPS2KT;
   }

   me.totalgalus = me.dependency["fuel"].getChild("total-gal_us").getValue();

   # on ground
   if( me.groundkt < me.FLIGHTKT ) {
       me.groundkt = me.SUBSONICKT;
       me.galusph = me.SUBSONICKGPH;
   }
   else {
       # gauge is NOT REAL
       me.galusph = me.dependency["fuel"].getNode("fuel-flow-gal_us_ph").getValue();
   }

   me.altitudeft = me.noinstrument["altitude"].getValue();
   selectft = me.dependency["autoflight"].getChild("dial-altitude-ft").getValue();
   me.last = constant.FALSE;


   # waypoint
   for( var i = 2; i >= 0; i = i-1 ) {
        if( i < 2 ) {
            id = me.dependency["waypoint"][i].getChild("id").getValue();
            distnm = me.dependency["waypoint"][i].getChild("dist").getValue();
            targetft = selectft;
        }

        # last
        else {
            id = "";
            child = me.dependency["route-manager"].getNode("wp-last/id");
            if( child != nil ) {
                id = child.getValue();
            } 
            distnm = me.dependency["route-manager"].getNode("wp-last/dist").getValue(); 
        }

        fuelgalus = me.estimatefuelgalus( id, distnm );
        speedfpm = me.estimatespeedfpm( id, distnm, targetft );
        
        display = constant.TRUE;
        if( fuelgalus == me.NOFUELGALUS ) {
            display = constant.FALSE;
        }
        me.itself["waypoint"][i].getChild("fuel").setValue(display);
        
        display = constant.TRUE;
        if( speedfpm == me.NOSPEEDFPM ) {
            display = constant.FALSE;
        }
        me.itself["waypoint"][i].getChild("speed").setValue(display);

        # display for FDM debug, or navigation
        me.itself["waypoint"][i].getChild("fuel-gal_us").setValue(int(math.round(fuelgalus)));
        me.itself["waypoint"][i].getChild("speed-fpm").setValue(int(math.round(speedfpm)));
   }
}

Navigation.estimatespeedfpm = func( id, distnm, targetft ) {
   var speedfpm = me.NOSPEEDFPM;
   var minutes = 0.0;

   if( id != "" and distnm != nil ) {
       # last waypoint at sea level
       if( !me.last ) {
           targetft = me.itself["root-ctrl"].getChild("destination-ft").getValue();
           me.last = constant.TRUE;
       }

       minutes = ( distnm / me.groundkt ) * constant.HOURTOMINUTE;
       speedfpm = ( targetft - me.altitudeft ) / minutes;
   }

   return speedfpm;
}

Navigation.estimatefuelgalus = func( id, distnm ) {
   var fuelgalus = me.NOFUELGALUS;
   var ratio = 0.0;

   if( id != "" and distnm != nil ) {
       ratio = distnm / me.groundkt;
       fuelgalus = me.galusph * ratio;
       fuelgalus = me.totalgalus - fuelgalus;
       if( fuelgalus < 0 ) {
           fuelgalus = 0;
       }
   }

   return fuelgalus;
}

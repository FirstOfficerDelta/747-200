# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =========
# SEAT RAIL
# =========

SeatRail = {};

SeatRail.new = func {
   var obj = { parents : [SeatRail,System.new("/systems/human")],

               RAILSEC : 5.0,

               FLIGHT : 0.0,
               PARK : 1.0
         };


   obj.init();

   return obj;
}

SeatRail.init = func {
}

SeatRail.toggle = func( seat ) {
   me.roll(me.itself[seat].getChild("stowe-norm").getPath());
}

# roll on rail
SeatRail.roll = func( path ) {
   var pos = getprop(path);

   if( pos == me.FLIGHT ) {
       interpolate( path, me.PARK, me.RAILSEC );
   }
   elsif( pos == me.PARK ) {
       interpolate( path, me.FLIGHT, me.RAILSEC );
   }
}


# ====
# CREW
# ====

Crew = {};

Crew.new = func {
   var obj = { parents : [Crew,System.new("/systems/crew")],
   
               autopilotsystem : nil,
               flightsystem : nil,
               fuelsystem : nil
   };

   obj.init();

   return obj;
}

Crew.init = func {
}

Crew.set_relation = func( autopilot, flight, fuel ) {
   me.autopilotsystem = autopilot;
   me.flightsystem = flight;
   me.fuelsystem = fuel;
}

Crew.startupexport = func {
   me.statecron();
}

Crew.statecron = func {
   var result = constant.TRUE;
   var found = constant.TRUE;
   var state = "";
   
   if( me.noinstrument["state"] != nil ) {
       state = me.noinstrument["state"].getValue();
   }
   
   if( state == "" ) {
       found = constant.FALSE;
   }
   
   if( state == "takeoff" ) {
       setprop("/controls/autoflight/dial-heading-deg", getprop("/orientation/heading-magnetic-deg"));
       
       # 20 degrees and slats
       controls.flapsDown(1);
       controls.flapsDown(1);
       controls.flapsDown(1);
       controls.flapsDown(1);
    
       me.send_fuel( constantaero.FUELTAKEOFF );
       me.send_state( state );
   }
   
   elsif( state == "cruise" ) {
       setprop("/controls/autoflight/dial-heading-deg", getprop("/orientation/heading-magnetic-deg"));
       
       autopilotsystem.aptogglealtitudeexport();
       autopilotsystem.apengageexport();
       
       autothrottlesystem.attoggleexport();
           
       me.send_fuel( constantaero.FUELCRUISE );
       me.send_state( state );
   }
   
   elsif( state == "descent" ) {
       setprop("/controls/autoflight/dial-heading-deg", getprop("/orientation/heading-magnetic-deg"));
       
       autopilotsystem.aptogglealtitudeexport();
       autopilotsystem.apengageexport();
       
       autothrottlesystem.attoggleexport();
           
       me.send_fuel( constantaero.FUELDESCENT );
       me.send_state( state );
   }
   
   elsif( state == "approach" ) {
       setprop("/controls/autoflight/dial-heading-deg", getprop("/orientation/heading-magnetic-deg"));
       
       autopilotsystem.aptogglealtitudeexport();
       autopilotsystem.apengageexport();
       
       autothrottlesystem.attoggleexport();
           
       me.send_fuel( constantaero.FUELDESCENT );
       me.send_state( state );
   }
   
   elsif( state == "landing" ) {
       setprop("/controls/autoflight/dial-heading-deg", getprop("/orientation/heading-magnetic-deg"));
       
       autopilotsystem.aptogglealtitudeexport();
       autopilotsystem.apengageexport();
       
       autothrottlesystem.attoggleexport();
       
       # 30 degrees and slats
       controls.flapsDown(1);
       controls.flapsDown(1);
       controls.flapsDown(1);
       controls.flapsDown(1);
       controls.flapsDown(1);
       controls.flapsDown(1);
      
       me.flightsystem.spoilersexport(1);
           
       me.send_fuel( constantaero.FUELLANDING );
       me.send_state( state );
   }
   
   elsif( state == "parking" ) {
           
       me.send_fuel( constantaero.FUELMIN );
       me.send_state( state );
   }
   
   else {
       result = constant.TRUE;
   }
}

Crew.send_state = func( targetstate ) {
   var message = "";
   
   message = "747 state set at " ~ targetstate;
   print(message);
}

Crew.send_fuel = func( preset ) {
   var comment = me.dependency["filling"][preset].getChild("comment").getValue();
       
   me.dependency["fuel"].setValue(comment);
   me.fuelsystem.menuexport();
}

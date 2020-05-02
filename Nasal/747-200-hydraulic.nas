# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =====
# DOORS
# =====

Doors = {};

Doors.new = func {
   var obj = { parents : [Doors,System.new("/systems/doors")],

               seat : SeatRail.new(),
 
               flightdeck : nil,
               exit : nil,
               cargobulk : nil,
               cargoaft : nil,
               cargoforward : nil
         };

   obj.init();

   return obj;
};

Doors.init = func {
   me.flightdeck = aircraft.door.new(me.itself["root-ctrl"].getNode("crew/flightdeck").getPath(), 8.0);
   me.exit = aircraft.door.new(me.itself["root-ctrl"].getNode("crew/exit").getPath(), 8.0);
   me.cargobulk = aircraft.door.new(me.itself["root-ctrl"].getNode("cargo/bulk").getPath(), 12.0);
   me.cargoaft = aircraft.door.new(me.itself["root-ctrl"].getNode("cargo/aft").getPath(), 12.0);
   me.cargoforward = aircraft.door.new(me.itself["root-ctrl"].getNode("cargo/forward").getPath(), 12.0);
}

Doors.amber_cargo_doors = func {
   var result = constant.FALSE;

   if( me.itself["root-ctrl"].getNode("cargo").getNode("forward").getChild("position-norm").getValue() > 0.0 or
       me.itself["root-ctrl"].getNode("cargo").getNode("aft").getChild("position-norm").getValue() > 0.0 or
       me.itself["root-ctrl"].getNode("cargo").getNode("bulk").getChild("position-norm").getValue() > 0.0 or
       me.itself["root-ctrl"].getNode("cargo").getChild("position-norm").getValue() > 0.0 ) {
       result = constant.TRUE;
   }

   return result;
}

Doors.seatexport = func( seat ) {
   me.seat.toggle( seat );
}

Doors.flightdeckexport = func {
   me.flightdeck.toggle();
}

Doors.exitexport = func {
   me.exit.toggle();
}

Doors.cargobulkexport = func {
   me.cargobulk.toggle();
}

Doors.cargoaftexport = func {
   me.cargoaft.toggle();
}

Doors.cargoforwardexport = func {
   me.cargoforward.toggle();
}


# ===========
# GEAR SYSTEM
# ===========

Gear = {};

Gear.new = func {
   var obj = { parents : [Gear,System.new("/systems/gear")],

               FLIGHTSEC : 2.0,

               STEERINGKT : 40
         };

   obj.init();

   return obj;
};

Gear.init = func {
   aircraft.steering.init(me.itself["root-ctrl"].getChild("brake-steering").getPath());
}

Gear.steeringexport = func {
   var result = 0.0;

   # taxi with steering wheel, rudder pedal at takeoff
   if( me.noinstrument["airspeed"].getValue() < me.STEERINGKT ) {

       # except forced by menu
       if( !me.dependency["steering"].getChild("pedal").getValue() ) {
           result = 1.0;
       }
   }

   me.dependency["steering"].getChild("wheel").setValue(result);
}

Gear.schedule = func {
   me.steeringexport();
}

Gear.green_gear_down = func {
   var result = constant.FALSE;

   if( me.itself["gear"][0].getChild("position-norm").getValue() == 1.0 and
       me.itself["gear"][1].getChild("position-norm").getValue() == 1.0 and
       me.itself["gear"][2].getChild("position-norm").getValue() == 1.0 ) {
       result = constant.TRUE;
   }

   return result;
}


# =======
# TRACTOR
# =======

Tractor = {};

Tractor.new = func {
   var obj = { parents : [Tractor,System.new("/systems/tractor")],

               TRACTORSEC : 10.0,

               SPEEDFPS : 5.0,
               STOPFPS : 0.0,

               CONNECTED : 1.0,
               DISCONNECTED : 0.0,

               disconnecting : constant.FALSE,

               initial : nil
             };

# user customization
   obj.init();

   return obj;
};

Tractor.init = func {
}

Tractor.schedule = func {
   if( me.itself["root-ctrl"].getChild("pushback").getValue() ) {
       me.start();
   }

   me.move();
}

Tractor.move = func {
   if( me.itself["root"].getChild("pushback").getValue() and !me.disconnecting ) {
       var status = "";
       var latlon = geo.aircraft_position();
       var rollingmeter = latlon.distance_to( me.initial );

       status = sprintf(rollingmeter, "1f.0");

       # wait for tractor connect
       if( me.dependency["pushback"].getChild("position-norm").getValue() == me.CONNECTED ) {
           var ratefps = math.sgn( me.itself["root-ctrl"].getChild("distance-m").getValue() ) * me.SPEEDFPS;

           me.dependency["pushback"].getChild("target-speed-fps").setValue( ratefps );
       }

       if( rollingmeter >= math.abs( me.itself["root-ctrl"].getChild("distance-m").getValue() ) ) {
           # wait for tractor disconnect
           me.disconnecting = constant.TRUE;

           me.dependency["pushback"].getChild("target-speed-fps").setValue( me.STOPFPS );
           interpolate(me.dependency["pushback"].getChild("position-norm").getPath(), me.DISCONNECTED, me.TRACTORSEC);

           status = "";
       }

       me.itself["root"].getChild("distance-m").setValue( status );
   }

   # tractor disconnect
   elsif( me.disconnecting ) {
       if( me.dependency["pushback"].getChild("position-norm").getValue() == me.DISCONNECTED ) {
           me.disconnecting = constant.FALSE;

           me.dependency["pushback"].getChild("enabled").setValue( constant.FALSE );

           # interphone to copilot
           me.itself["root"].getChild("clear").setValue( constant.TRUE );
           me.itself["root"].getChild("pushback").setValue( constant.FALSE );
       }
   }
}

Tractor.start = func {
   # must wait for end of current movement
   if( !me.itself["root"].getChild("pushback").getValue() ) {
       me.disconnecting = constant.FALSE;

       me.initial = geo.aircraft_position();

       me.itself["root-ctrl"].getChild("pushback").setValue( constant.FALSE );
       me.itself["root"].getChild("pushback").setValue( constant.TRUE );
       me.itself["root"].getChild("clear").setValue( constant.FALSE );
       me.itself["root"].getChild("engine14").setValue( constant.FALSE );

       me.dependency["pushback"].getChild("enabled").setValue( constant.TRUE );
       interpolate(me.dependency["pushback"].getChild("position-norm").getPath(), me.CONNECTED, me.TRACTORSEC);
   }
}

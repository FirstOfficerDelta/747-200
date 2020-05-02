# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ============
# AUTOTHROTTLE
# ============

Autothrottle = {};

Autothrottle.new = func {
   var obj = { parents : [Autothrottle,System.new("/systems/autothrottle")],

               AUTOTHROTTLESEC : 2.0,

               AUTOMACHFEET : 0.0
         };

   obj.init();

   return obj;
};

Autothrottle.init = func {
   me.AUTOMACHFEET = me.itself["autoflight"].getChild("automach-ft").getValue();
}

# manual setting of speed with knob
Autothrottle.speedknobexport = func( sign ) {
   var result = constant.FALSE;

   if( me.has_lock_speed() ) {
       result = constant.TRUE;

       if( me.is_lock_speed() ) {
           var speedkt = me.itself["autoflight"].getChild("dial-speed-kt").getValue();
           
           speedkt = speedkt + 10 * sign;
           
           me.itself["autoflight"].getChild("dial-speed-kt").setValue(speedkt);
           me.itself["settings"].getChild("target-speed-kt").setValue(speedkt);
       }
       elsif( me.is_lock_mach() ) {
           var speedmach = me.itself["autoflight"].getChild("dial-mach").getValue();
           
           speedmach = speedmach + 0.1 * sign;
           
           me.itself["autoflight"].getChild("dial-mach").setValue(speedmach);
           me.itself["settings"].getChild("target-mach").setValue(speedmach);
       }
   }

   return result;
}

Autothrottle.schedule = func {
   var speedmode = me.itself["locks"].getChild("speed").getValue();

   # automatic swaps between kt and Mach
   if( speedmode != "" and speedmode != nil ) {
       me.atmode( speedmode );
   }
}

# speed of sound
Autothrottle.getsoundkt = func {
   # simplification
   var speedkt = me.noinstrument["airspeed"].getValue();
   var speedmach = me.noinstrument["mach"].getValue();
   var soundkt = speedkt / speedmach;

   return soundkt;
}

Autothrottle.is_vertical = func {
   var result = constant.FALSE;

   var speedmode = me.itself["locks"].getChild("speed").getValue();

   if( speedmode == "vertical-speed-with-throttle" ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.is_glide = func {
   var result = constant.FALSE;

   var speedmode = me.itself["locks"].getChild("speed").getValue();

   if( speedmode == "gs1-with-throttle" ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.altmach = func {
   var result = constant.FALSE;

   var altft = constant.nonil( me.dependency["altimeter"].getChild("indicated-altitude-ft").getValue() );

   if( altft >= me.AUTOMACHFEET ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.atmode = func( speedmode ) {
   var speedkt = 0.0;
   var speedmach = 0.0;

   if( !me.is_vertical() and !me.is_glide() ) {
       if( me.altmach() ) {
           if( speedmode != "mach-with-throttle" ) {
               speedkt = me.itself["settings"].getChild("target-speed-kt").getValue();
               speedmach = speedkt / me.getsoundkt();
               me.itself["settings"].getChild("target-mach").setValue(speedmach);
               me.itself["autoflight"].getChild("dial-mach").setValue(speedmach);
               me.itself["locks"].getChild("speed").setValue("mach-with-throttle");
           }
       }
       else {
           if( speedmode != "speed-with-throttle" ) {
               if( speedmode == "mach-with-throttle" ) {
                   speedmach = me.itself["settings"].getChild("target-mach").getValue();
                   speedkt = speedmach * me.getsoundkt();
                   me.itself["settings"].getChild("target-speed-kt").setValue(speedkt);
                   me.itself["autoflight"].getChild("dial-speed-kt").setValue(speedkt);
               }
               me.itself["locks"].getChild("speed").setValue("speed-with-throttle");
           }
       }
   }
}

# the autothrottle switch may be still activated
Autothrottle.atdisable = func {
   me.itself["autoflight"].getChild("autothrottle-engage").setValue(constant.FALSE);
   me.itself["locks"].getChild("speed").setValue("");
}

Autothrottle.atsend = func {
   var speedmode = me.itself["locks"].getChild("speed").getValue();

   me.atenable(speedmode);
}

Autothrottle.atenable = func( mode ) {
   if( me.itself["autoflight"].getChild("autothrottle-engage").getValue() ) {
       me.itself["locks"].getChild("speed").setValue(mode);
   }
   else {
       me.atdisable();
   }
}

# toggle autothrottle (ctrl-S)
Autothrottle.attoggleexport = func {
   if( me.itself["autoflight"].getChild("autothrottle-engage").getValue() ) {
       me.atdisable();
   }
   else {
       me.itself["autoflight"].getChild("autothrottle-engage").setValue(constant.TRUE);

       if( me.altmach() ) {
           var speedmach = me.itself["autoflight"].getChild("dial-mach").getValue();
           me.itself["settings"].getChild("target-mach").setValue(speedmach);
           me.itself["locks"].getChild("speed").setValue("mach-with-throttle");
       }
       else {
           var speedkt = me.itself["autoflight"].getChild("dial-speed-kt").getValue();
           me.itself["settings"].getChild("target-speed-kt").setValue(speedkt);
           me.itself["locks"].getChild("speed").setValue("speed-with-throttle");
       }
   }
}

Autothrottle.idle = func {
   for(var i=0; i<constantaero.NBENGINES; i=i+1) {
       me.dependency["engine"][i].getChild("throttle").setValue(0);
   }
}

Autothrottle.has_lock_speed = func {
   var result= constant.FALSE;

   var speedmode = me.itself["locks"].getChild("speed").getValue();

   if( speedmode != "" and speedmode != nil ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.is_lock_speed = func {
   var result = constant.FALSE;

   var speedmode = me.itself["locks"].getChild("speed").getValue();

   if( speedmode == "speed-with-throttle" ) {
       result = constant.TRUE;
   }

   return result;
}

Autothrottle.is_lock_mach = func {
   var result = constant.FALSE;

   var speedmode = me.itself["locks"].getChild("speed").getValue();

   if( speedmode == "mach-with-throttle" ) {
       result = constant.TRUE;
   }

   return result;
}

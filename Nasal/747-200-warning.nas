# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ===============================
# GROUND PROXIMITY WARNING SYSTEM
# ===============================

Gpws = {};

Gpws.new = func {
   var obj = { parents : [Gpws,System.new("/instrumentation/gpws")],

               FLIGHTFT : 2500,
               GEARFT : 500,
               GROUNDFT : 200,

               FLIGHTFPS : -50,
               GROUNDFPS : -15,
               TAXIFPS : -5,                                   # taxi is not null

               GEARDOWN : 1.0
         };

   obj.init();

   return obj;
};

Gpws.init = func {
}

Gpws.red_pull_up = func {
   var result = constant.FALSE;
   var aglft = me.dependency["radio-altimeter"].getChild("indicated-altitude-ft").getValue();
   var verticalfps = me.dependency["ivsi"].getChild("indicated-speed-fps").getValue();
   var gearpos = me.dependency["gear"].getChild("position-norm").getValue();

   if( aglft == nil or verticalfps == nil or gearpos == nil ) {
      result = constant.FALSE;
   }

   # 3000 ft/min
   elsif( aglft < me.FLIGHTFT and verticalfps < me.FLIGHTFPS ) {
       result = constant.TRUE;
   }

   # 900 ft/min
   elsif( aglft < me.GROUNDFT and verticalfps < me.GROUNDFPS ) {
       result = constant.TRUE;
   }

   # gear not down
   elsif( aglft < me.GEARFT and verticalfps < me.TAXIFPS and gearpos < me.GEARDOWN ) {
       result = constant.TRUE;
   }

   return result;
}


# ==============
# WARNING SYSTEM
# ==============

Warning = {};

Warning.new = func {
   var obj = { parents : [Warning,System.new("/systems/warning")],

               doorsystem : nil,
               enginesystem : nil,
               gearsystem : nil,

               gpwssystem : Gpws.new()
         };

   obj.init();

   return obj;
};

Warning.init = func {
}

Warning.set_relation = func( door, engine, gear ) {
   me.doorsystem = door;
   me.enginesystem = engine;
   me.gearsystem = gear;
}

Warning.schedule = func {
   me.sendred( "pull-up", me.gpwssystem.red_pull_up() );

   me.sendamber( "cargo-doors", 0, me.doorsystem.amber_cargo_doors() );
   for (var i = 0; i < constantaero.NBENGINES; i=i+1) {
        me.sendamber( "engine-oil-pressure", i, me.enginesystem.amber_oil_pressure( i ) );
   }

   me.sendgreen( "gear-down", me.gearsystem.green_gear_down() );
}

Warning.sendgreen = func( name, value ) {
   if( me.itself["green"].getChild(name).getValue() != value ) {
       me.itself["green"].getChild(name).setValue( value );
   }
}

Warning.sendamber = func( name, num, value ) {
   if( num == 0 ) {
       if( me.itself["amber"].getChild(name).getValue() != value ) {
           me.itself["amber"].getChild(name).setValue( value );
       }
   }
   else {
       var children = nil;

       children = me.itself["amber"].getChildren(name);

       if( children[num].getValue() != value ) {
           children[num].setValue( value );
       }
   }
}

Warning.sendred = func( name, value ) {
   if( me.itself["red"].getChild(name).getValue() != value ) {
       me.itself["red"].getChild(name).setValue( value );
   }
}

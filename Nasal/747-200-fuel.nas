# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ===========
# FUEL SYSTEM
# ===========

Fuel = {};

Fuel.new = func {
   var obj = { parents : [Fuel,System.new("/systems/fuel")],

               totalfuelinstrument : TotalFuel.new(),
               tanksystem : Tanks.new(),

               presets : 0                                      # saved state
         };

   obj.init();

   return obj;
};

Fuel.init = func {
   me.tanksystem.presetfuel();
   me.savestate();
}

Fuel.menuexport = func {
   me.tanksystem.menu();
   me.savestate();
}

Fuel.reinitexport = func {
   # restore for reinit
   me.itself["root"].getChild("presets").setValue(me.presets);

   me.tanksystem.presetfuel();
   me.savestate();
}

Fuel.savestate = func {
   # backup for reinit
   me.presets = me.itself["root"].getChild("presets").getValue();
}

Fuel.schedule = func {
   me.totalfuelinstrument.schedule();
}


# =====
# TANKS
# =====

# adds an indirection to convert the tank name into an array index.

Tanks = {};

Tanks.new = func {
# tank contents, to be initialised from XML
   var obj = { parents : [Tanks], 

               pumpsystem : Pump.new(),

               CONTENTLB : { "C" : 0.0, "1" : 0.0, "2" : 0.0, "3" : 0.0, "4" : 0.0, "R1" : 0.0, "R4" : 0.0 },
               TANKINDEX : { "C" : 0, "1" : 1, "2" : 2, "3" : 3, "4" : 4, "R1" : 5, "R4" : 6 },
               TANKNAME : [ "C", "1", "2", "3", "4", "R1", "R4" ],
               nb_tanks : 0,

               dailogpath : nil,
               fillingspath : nil,
               systempath : nil,
               tankspath : nil
        };

   obj.init();

   return obj;
}

Tanks.init = func {
   me.systempath = props.globals.getNode("/systems/fuel");

   me.dialogpath = me.systempath.getNode("tanks/dialog");
   me.tankspath = props.globals.getNode("/consumables/fuel").getChildren("tank");
   me.fillingspath = me.systempath.getChild("tanks").getChildren("filling");

   me.nb_tanks = size(me.tankspath);

   me.initcontent();
}

# fuel initialization
Tanks.initcontent = func {
   var densityppg = 0.0;

   for( var i=0; i < me.nb_tanks; i=i+1 ) {
        densityppg = me.tankspath[i].getChild("density-ppg").getValue();
        me.CONTENTLB[me.TANKNAME[i]] = me.tankspath[i].getChild("capacity-gal_us").getValue() * densityppg;
   }
}

# change by dialog
Tanks.menu = func {
   var value = 0.0;

   value = me.dialogpath.getValue();
   for( var i=0; i < size(me.fillingspath); i=i+1 ) {
        if( me.fillingspath[i].getChild("comment").getValue() == value ) {
            me.load( i );

            # for aircraft-data
            me.systempath.getChild("presets").setValue(i);
            break;
        }
   }
}

# fuel configuration
Tanks.presetfuel = func {
   var fuel = 0;
   var dialog = "";

   # default is 0
   fuel = me.systempath.getChild("presets").getValue();
   if( fuel == nil ) {
       fuel = 0;
   }

   if( fuel < 0 or fuel >= size(me.fillingspath) ) {
       fuel = 0;
   } 

   # copy to dialog
   dialog = me.dialogpath.getValue();
   if( dialog == "" or dialog == nil ) {
       value = me.fillingspath[fuel].getChild("comment").getValue();
       me.dialogpath.setValue(value);
   }

   me.load( fuel );
}

Tanks.load = func( fuel ) {
   var presets = nil;
   var child = nil;
   var level = 0.0;

   presets = me.fillingspath[fuel].getChildren("tank");
   for( var i=0; i < size(presets); i=i+1 ) {
        child = presets[i].getChild("level-gal_us");
        if( child != nil ) {
            level = child.getValue();
        }

        # new load through dialog
        else {
            level = me.CONTENTLB[me.TANKNAME[i]] * constant.LBTOGALUS;
        } 
        me.pumpsystem.setlevel(i, level);
   } 
}

Tanks.transfertanks = func( dest, sour, pumplb ) {
   me.pumpsystem.transfertanks( dest, me.CONTENTLB[me.TANKNAME[dest]], sour, pumplb );
}


# ==========
# FUEL PUMPS
# ==========

# does the transfers between the tanks

Pump = {};

Pump.new = func {
   var obj = { parents : [Pump],

               tanks : nil 
         };

   obj.init();

   return obj;
}

Pump.init = func {
   me.tanks = props.globals.getNode("/consumables/fuel").getChildren("tank");
}

Pump.getlevel = func( index ) {
   var tankgalus = 0.0;

   tankgalus = me.tanks[index].getChild("level-gal_us").getValue();

   return tankgalus;
}

Pump.setlevel = func( index, levelgalus ) {
   me.tanks[index].getChild("level-gal_us").setValue(levelgalus);
}

Pump.transfertanks = func( idest, contentdestlb, isour, pumplb ) {
   var tankdestlb = 0.0;
   var tankdestgalus = 0.0;
   var maxdestlb = 0.0;
   var tanksourlb = 0.0;
   var tanksourgalus = 0.0;
   var maxsourlb = 0.0;

   tankdestlb = me.tanks[idest].getChild("level-gal_us").getValue() * constant.GALUSTOLB;
   maxdestlb = contentdestlb - tankdestlb;
   tanksourlb = me.tanks[isour].getChild("level-gal_us").getValue() * constant.GALUSTOLB;
   maxsourlb = tanksourlb - 0;

   # can fill destination
   if( maxdestlb > 0 ) {
       # can with source
       if( maxsourlb > 0 ) {
           if( pumplb <= maxsourlb and pumplb <= maxdestlb ) {
               tanksourlb = tanksourlb - pumplb;
               tankdestlb = tankdestlb + pumplb;
           }
           # destination full
           elsif( pumplb <= maxsourlb and pumplb > maxdestlb ) {
               tanksourlb = tanksourlb - maxdestlb;
               tankdestlb = contentdestlb;
           }
           # source empty
           elsif( pumplb > maxsourlb and pumplb <= maxdestlb ) {
               tanksourlb = 0;
               tankdestlb = tankdestlb + maxsourlb;
           }
           # source empty and destination full
           elsif( pumplb > maxsourlb and pumplb > maxdestlb ) {
               # source empty
               if( maxdestlb > maxsourlb ) {
                   tanksourlb = 0;
                   tankdestlb = tankdestlb + maxsourlb;
               }
               # destination full
               elsif( maxdestlb < maxsourlb ) {
                   tanksourlb = tanksourlb - maxdestlb;
                   tankdestlb = contentdestlb;
               }
               # source empty and destination full
               else {
                  tanksourlb = 0;
                  tankdestlb = contentdestlb;
               }
           }
           # user sees emptying first
           # JBSim only sees US gallons
           tanksourgalus = tanksourlb / constant.GALUSTOLB;
           me.tanks[isour].getChild("level-gal_us").setValue(tanksourgalus);
           tankdestgalus = tankdestlb / constant.GALUSTOLB;
           me.tanks[idest].getChild("level-gal_us").setValue(tankdestgalus);
       }
   }
}


# ==========
# TOTAL FUEL
# ==========
TotalFuel = {};

TotalFuel.new = func {
   var obj = { parents : [TotalFuel,System.new("/instrumentation/fuel")],

               STEPSEC : 1.0,                     # 3 s would be enough, but needs 1 s for kg/h

               nb_tanks : 0
         };

   obj.init();

   return obj;
};

TotalFuel.init = func {
   me.nb_tanks = size(me.dependency["tank"]);
}

# total of fuel in US gal
TotalFuel.schedule = func {
   var fuelgalus = 0.0;

   # last total
   var tanksgalus = me.itself["root"].getChild("total-gal_us").getValue();

   # new total
   for(var i=0; i<me.nb_tanks; i=i+1) {
       fuelgalus = fuelgalus + me.dependency["tank"][i].getChild("level-gal_us").getValue();
   }
   me.itself["root"].getChild("total-gal_us").setValue(fuelgalus);


   me.flow(tanksgalus, fuelgalus);
}

TotalFuel.flow = func(tanksgalus, fuelgalus) {
   var stepgalus = 0.0;
   var fuelgaluspmin = 0.0;
   var fuelgalusph = 0.0;

   # ======================================================================
   # - MUST BE CONSTANT with speed up : pumping is accelerated.
   # - not real, used to check errors in pumping.
   # - JSBSim consumes more with speed up, at the same indicated fuel flow.
   # ======================================================================
   stepgalus = tanksgalus - fuelgalus;
   fuelgaluspmin = stepgalus * constant.MINUTETOSECOND / ( me.STEPSEC );
   fuelgalusph = fuelgaluspmin * constant.HOURTOMINUTE;

   # not real
   me.itself["root"].getChild("fuel-flow-gal_us_ph").setValue(math.round(fuelgalusph));
}

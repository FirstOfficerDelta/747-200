# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =============
# 747 CONSTANTS
# =============

ConstantAero = {};

ConstantAero.new = func {
   var obj = { parents : [ConstantAero],
               
               FUELLANDING : 0,
               FUELTAKEOFF : 1,
               FUELMIN : 2,
               FUELCRUISE : 3,
               FUELDESCENT : 4,

               FULLLB : 833000,
               LANDINGLB : 630000,
               EMPTYLB : 376330,

               NBENGINES : 4,
               NBINS : 3,

# AGL altitude when on ground : radio altimeter is above gear
# (Z height of center of gravity minus Z height of main landing gear)
               AGLFT : 13,

# AGL altitude, where the gears touch the ground
               AGLTOUCHFT : 17
         };

   return obj;
}

ConstantAero.weightratio = func( weightlb, empty, full ) {
    var value = 0.0;
    var ratio = 0.0;

    if( weightlb > me.FULLLB ) {
        valuekt = full;
    }
    elsif( weightlb < me.EMPTYLB ) {
        valuekt = empty;
    }
    else {
        ratio = ( me.FULLLB - weightlb ) / ( me.FULLLB - me.EMPTYLB );
        value = full + ( empty - full ) * ratio;
    }

    return value;
}


# =========
# CONSTANTS
# =========

Constant = {};

Constant.new = func {
   var obj = { parents : [Constant],

# angles
               DEG360 : 360,
               DEG180 : 180,
               DEG90 : 90,

# no boolean
               TRUE : 1.0,
               FALSE : 0.0,

# property not yet created at startup (should through XML)
               DELAYEDNODE : 1,

# ---------------
# unit conversion
# ---------------
# length
               FEETTONM : 0.0001645788,

# time
               HOURTOMINUTE : 60,
               HOURTOSECOND : 3600,
               MINUTETOSECOND : 60,
               MINUTETODECIMAL : 0.01,

# weight
               GALUSTOLB : 6.6,                        # 1 US gallon = 6.6 pound
               LBTOGALUS : 0.0
         };

   obj.init();

   return obj;
};

Constant.init = func {
   me.LBTOGALUS = 1 / me.GALUSTOLB;
}

Constant.nonil = func ( value ) {
   if( value == nil ) {
       value = 0.0;
   }

   return value;
}


# ======
# SYSTEM
# ======

# for inheritance, the system must be the last of parents.
System = {};

# not called by child classes !!!
System.new = func( path, subpath = "" ) {
   var obj = { parents : [System],

               SYSSEC : 0.0,                               # to be defined !

               ready : constant.FALSE,                     # waits for end of initialization

               RELOCATIONFT : 0.0,                         # max descent speed around 6000 feet/minute.

               altseaft : 0.0,

               dependency : {},
               itself : {},
               noinstrument : {}
         };

   obj.init( path, subpath );
   
   return obj;
};

System.init = func( path, subpath ) {
   var fullpath = path;
   var ctrlpath = "";


   ctrlpath = string.replace(path,"systems","controls");
   if( fullpath == ctrlpath ) {
       ctrlpath = string.replace(path,"instrumentation","controls");
   }

   # reserved entry
   if( subpath == "" ) {
       # instrumentation/fuel
       me.itself["root"] = props.globals.getNode(path);

       # controls/fuel
       me.itself["root-ctrl"] = props.globals.getNode(ctrlpath);
   }
   else {
       # instrumentation/fuel-consumed[0]
       # instrumentation/fuel-consumed[1]
       # instrumentation/fuel-consumed[2]
       if( find("instrumentation/", fullpath) < 0 and
           find("systems/", fullpath ) < 0 ) {
           fullpath = fullpath ~ "/" ~ subpath;
       }

       # systems/engines/engine
       me.itself["root"] = props.globals.getNode(path).getChildren(subpath);

       # controls/engines/engine
       me.itself["root-ctrl"] = props.globals.getNode(ctrlpath).getChildren(subpath);
   }

   fullpath = fullpath ~ "/relations";

   me.loadtree( fullpath ~ "/dependency", me.dependency );
   me.loadtree( fullpath ~ "/itself", me.itself );
   me.loadtree( fullpath ~ "/noinstrument", me.noinstrument );
}

System.set_rate_ancestor = func( rates ) {
   me.SYSSEC = rates;

   me.RELOCATIONFT = constantaero.MAXFPM / ( constant.MINUTETOSECOND / me.SYSSEC );
}

# property access is faster through its node, than parsing its string
System.loadtree = func( path, table ) {
   var children = nil;
   var subchildren = nil;
   var name = "";
   var component = "";
   var subcomponent = "";
   var value = "";

   if( props.globals.getNode(path) != nil ) {
       children = props.globals.getNode(path).getChildren();
       foreach( var c; children ) {
          name = c.getName();
          subchildren = c.getChildren();

          # <dependency>
          #  <engine>
          #   <component>/engines</component>
          #   <subcomponent>engine</subcomponent>
          #  </engine>
          if( size(subchildren) > 0 ) {
              component = c.getChild("component").getValue();
              subcomponent = c.getChild("subcomponent").getValue();
              table[name] = props.globals.getNode(component).getChildren(subcomponent);
          }

          #  <altimeter>/instrumentation/altimeter[0]</altimeter>
          # </dependency>
          else {
              value = c.getValue();
              table[name] = props.globals.getNode(value);
          }
      }
   }
}

System.is_moving = func {
   var result = constant.FALSE;

   # must exist in XML !
   var aglft = me.noinstrument["agl"].getValue();
   var speedkt = me.noinstrument["speed"].getValue();

   if( aglft >=  constantaero.AGLTOUCHFT or speedkt >= constantaero.TAXIKT ) {
       result = constant.TRUE;
   }

   return result;
}

System.is_relocating = func {
   var result = constant.FALSE;
   var variationftpm = 0.0;

   # must exist in XML !
   var altft = me.noinstrument["altitude"].getValue();

   # relocation in flight, or at another airport
   variationftpm = altft - me.altseaft;
   if( variationftpm < - me.RELOCATIONFT or variationftpm > me.RELOCATIONFT ) {
       result = constant.TRUE;
   }

   me.altseaft = altft;

   return result;
}

System.is_ready = func {
    # if there is electrical power, there should be also hydraulics
    if( !me.ready ) {
        # must exist in XML !
        me.ready = me.dependency["electric"].getChild("specific").getValue();
    }

    return me.ready;
}

System.speed_ratesec = func( steps ) {
   var speedup = me.noinstrument["speed-up"].getValue();

   if( speedup > 1 ) {
       steps = steps / speedup;
   }

   return steps;
}

System.speed_timesec = func( steps ) {
   var speedup = me.noinstrument["speed-up"].getValue();

   if( speedup > 1 ) {
       steps = steps * speedup;
   }

   return steps;
}

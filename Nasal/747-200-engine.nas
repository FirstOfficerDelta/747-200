# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# =======
# ENGINES
# =======

Engine = {};

Engine.new = func {
   var obj = { parents : [Engine,System.new("/systems/engines")],

               OILPRESSURELOWPSI : 35
         };

   obj.init();

   return obj;
};

Engine.init = func {
}

Engine.amber_oil_pressure = func( num ) {
   var result = constant.FALSE;

   if( me.itself["engine"][num].getChild("oil-pressure-psi").getValue() <= me.OILPRESSURELOWPSI ) {
       result = constant.TRUE;
   }

   return result;
}

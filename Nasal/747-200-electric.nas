# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ========
# LIGHTING
# ========

Lighting = {};

Lighting.new = func {
   var obj = { parents : [Lighting,System.new("/systems/lighting")],
               
               LIGHTON : 1,              # white lighting
               LIGHTOFF : 0
         };

   obj.init();

   return obj;
};

Lighting.init = func {
}

Lighting.flashlightexport = func {
   var switch = me.LIGHTOFF;
   
   if( me.itself["root-ctrl"].getChild("flash-light").getValue() ) {
       switch = me.LIGHTON;
   }
   
   me.itself["flash-light"].setValue(switch);
}

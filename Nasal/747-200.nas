# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron

# current nasal version doesn't accept :
# - too many operations on 1 line.
# - variable with hyphen (?).



# ==============
# Initialization
# ==============

BoeingMain = {};

BoeingMain.new = func {
   var obj = { parents : [BoeingMain],
   
               timer1sec : nil,
               timer2sec : nil,
               timer3sec : nil,
               timer5sec : nil,
               timer60sec : nil,
               timerstartup : nil
         };

   obj.init();

   return obj;
}

BoeingMain.putinrelation = func {
   autopilotsystem.set_relation( autothrottlesystem );
   warningsystem.set_relation( doorsystem, enginesystem, gearsystem );
   
   crewcrew.set_relation( autopilotsystem, flightsystem, fuelsystem );
}

BoeingMain.statecron = func {
   crewcrew.startupexport();
}

# 1 s cron
BoeingMain.sec1cron = func {
   flightsystem.schedule();
   fuelsystem.schedule();
   warningsystem.schedule();
   daytimeinstrument.schedule();
}

# 2 s cron
BoeingMain.sec2cron = func {
   gearsystem.schedule();
}

# 3 s cron
BoeingMain.sec3cron = func {
   autopilotsystem.schedule();
   autothrottlesystem.schedule();
   INSinstrument.schedule();
   crewscreen.schedule();
}

# 5 s cron
BoeingMain.sec5cron = func {
   tractorexternal.schedule();
}

# 60 s cron
BoeingMain.sec60cron = func {
   engineercrew.veryslowschedule();
}

BoeingMain.savedata = func {
   aircraft.data.add("/controls/autoflight/fg-waypoint");
   aircraft.data.add("/controls/crew/clock");
   aircraft.data.add("/controls/environment/contrails");
   aircraft.data.add("/controls/fuel/reinit");
   aircraft.data.add("/controls/seat/arm/captain");
   aircraft.data.add("/controls/seat/arm/copilot");
   aircraft.data.add("/controls/seat/floating/recover");
   aircraft.data.add("/systems/fuel/presets");
   aircraft.data.add("/systems/seat/position/cargo-aft/x-m");
   aircraft.data.add("/systems/seat/position/cargo-aft/y-m");
   aircraft.data.add("/systems/seat/position/cargo-aft/z-m");
   aircraft.data.add("/systems/seat/position/cargo-forward/x-m");
   aircraft.data.add("/systems/seat/position/cargo-forward/y-m");
   aircraft.data.add("/systems/seat/position/cargo-forward/z-m");
   aircraft.data.add("/systems/seat/position/gear-well/x-m");
   aircraft.data.add("/systems/seat/position/gear-well/y-m");
   aircraft.data.add("/systems/seat/position/gear-well/z-m");
   aircraft.data.add("/systems/seat/position/observer/x-m");
   aircraft.data.add("/systems/seat/position/observer/y-m");
   aircraft.data.add("/systems/seat/position/observer/z-m");
}

# global variables in Boeing747 namespace, for call by XML
BoeingMain.instantiate = func {
   globals.Boeing747.constant = Constant.new();
   globals.Boeing747.constantaero = ConstantAero.new();

   globals.Boeing747.autopilotsystem = Autopilot.new();
   globals.Boeing747.autothrottlesystem = Autothrottle.new();
   globals.Boeing747.enginesystem = Engine.new();
   globals.Boeing747.fuelsystem = Fuel.new();
   globals.Boeing747.flightsystem = Flight.new();
   globals.Boeing747.gearsystem = Gear.new();
   globals.Boeing747.lightingsystem = Lighting.new();
   globals.Boeing747.warningsystem = Warning.new();

   globals.Boeing747.INSinstrument = Inertial.new();
   globals.Boeing747.daytimeinstrument = DayTime.new();

   globals.Boeing747.doorsystem = Doors.new();
   globals.Boeing747.seatsystem = Seats.new();

   globals.Boeing747.menuscreen = Menu.new();
   globals.Boeing747.crewscreen = Crewbox.new();

   globals.Boeing747.engineercrew = Virtualengineer.new();
   globals.Boeing747.crewcrew = Crew.new();

   globals.Boeing747.tractorexternal = Tractor.new();
}

# initialization
BoeingMain.init = func {
   aircraft.livery.init( "Aircraft/747-200/Models/Liveries",
                         "sim/model/livery/name",
                         "sim/model/livery/index" );

   me.instantiate();
   me.putinrelation();

   # schedule the 1st call
   me.timer1sec = maketimer(1, me, me.sec1cron);
   me.timer2sec = maketimer(2, me, me.sec2cron);
   me.timer3sec = maketimer(crewscreen.MENUSEC, me, me.sec3cron);
   me.timer5sec = maketimer(tractorexternal.TRACTORSEC, me, me.sec5cron);
   me.timer60sec = maketimer(60, me, me.sec60cron);

   me.timer1sec.simulatedTime = 1;
   me.timer2sec.simulatedTime = 1;
   me.timer3sec.simulatedTime = 1;
   me.timer5sec.simulatedTime = 1;
   me.timer60sec.simulatedTime = 1;

   me.timer1sec.start();
   me.timer2sec.start();
   me.timer3sec.start();
   me.timer5sec.start();
   me.timer60sec.start();

   # saved on exit, restored at launch
   me.savedata();
   
   # waits that systems are ready
   me.timerstartup = maketimer(2.0, me, me.statecron);
   me.timerstartup.singleShot = 1;
   me.timerstartup.start();
}

# state reset
BoeingMain.reinit = func {
   if( getprop("/controls/fuel/reinit") ) {
       # default is JSBSim state, which loses fuel selection.
       globals.Boeing747.fuelsystem.reinitexport();
   }
}


# object creation
boeing747L  = setlistener("/sim/signals/fdm-initialized", func { globals.Boeing747.main = BoeingMain.new(); removelistener(boeing747L); });

# state reset
boeing747L2 = setlistener("/sim/signals/reinit", func { globals.Boeing747.main.reinit(); });

(
s.options.numBuffers = 1024 * 256;
s.options.memSize = 8192 * 32;
s.options.numWireBufs = 2048;
s.options.maxNodes = 1024 * 32;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 2;

s.waitForBoot {
    // Only initialize SuperDirt if it isn't already running
    if (~dirt.isNil) {
        ~dirt = SuperDirt(2, s);
        ~dirt.start(57120, 0 ! 12);
        SuperDirt.default = ~dirt;
        s.latency = 0.8;

        // --- hsc3: Reload Listener ---
        if (~hsc3_oscFunc.isNil) {
            ~hsc3_oscFunc = OSCFunc({ |msg|
                \"hsc3: Syncing Server and SuperDirt...\".postln;
                fork {
                    s.sendMsg(\"/d_loadDir\", \"/home/numa/.local/share/SuperCollider/synthdefs/\");
                    s.sync;
                    SynthDescLib.global.read;
                    0.2.wait;
                    ~dirt.loadSynthDefs;
                    \"hsc3: Sync complete. All definitions ready.\".postln;
                    0.5.wait;
                    ~printCheatSheet.value;
  };
  }, '/hsc3/reload').fix;
			~printCheatSheet = {
       "".postln;
       \"--- hsc3 Sample Cheat Sheet ---\".postln;
       [\bd, \sn, \cp, \hh, \arpy, \casio, \drum].do { |name|
          if (~dirt.buffers[name].notNil) {
             (\"Sample '\" ++ name ++ \"' -> Buffer: \" ++ ~dirt.buffers[name][0].bufnum).postln;
          };
       };
       \"-------------------------------\".postln;
    };

    OSCFunc({ ~printCheatSheet.value; }, '/hsc3/cheat').fix;

    // ---------------------------
		};
		{ \"hsc3: OSC Listener has been installed\".postln; }

};
{
\"hsc3: OSC Listener already installed\".postln;
};
}

{
\"hsc3: SuperDirt already running, skipping init\".postln;
};
// --- Notify Emacs that SuperDirt and hsc3 are ready (Port 7777) ---
s.sync;
NetAddr(\"127.0.0.1\", 7777).sendMsg(\"/dirt/ready\", \"SuperDirt is ready\");
\"hsc3: SuperDirt is ready. Notifying Emacs on port 7777...\".postln;
};
)





(
s.options.numBuffers = 1024 * 256;
s.options.memSize = 8192 * 32;
s.options.numWireBufs = 2048;
s.options.maxNodes = 1024 * 32;
s.options.numOutputBusChannels = 2;
s.options.numInputBusChannels = 2;

s.waitForBoot {
    // Only initialize SuperDirt if it isn't already running
	(
    if (~dirt.isNil, {
        ~dirt = SuperDirt(2, s);
        ~dirt.start(57120, 0 ! 12);
        SuperDirt.default = ~dirt;
        s.latency = 0.8;

        // --- hsc3: Reload Listener ---
        if (~hsc3_oscFunc.isNil, {
            ~hsc3_oscFunc = OSCFunc({ |msg|
                "hsc3: Syncing Server and SuperDirt...".postln;
                fork {
                    s.sendMsg("/d_loadDir", "/home/numa/.local/share/SuperCollider/synthdefs/");
                    s.sync;
                    SynthDescLib.global.read;
                    0.2.wait;
                    ~dirt.loadSynthDefs;
                    "hsc3: Sync complete. All definitions ready.".postln;
                    0.5.wait;
                    ~printCheatSheet.value;};
			}, '/hsc3/reload').fix;
			"hsc3: OSC Listener INSTALLED on port 57120".postln;

			~printCheatSheet = {
               "".postln;
               "--- hsc3 Sample Cheat Sheet ---".postln;
               [\bd, \sn, \cp, \hh, \arpy, \casio, \drum].do { |name|
                   if (~dirt.buffers[name].notNil) {
				       ("Sample '" ++ name ++ "' -> Buffer: " ++ ~dirt.buffers[name][0].bufnum).postln;
			       };
               };
               "-------------------------------".postln;
            };
            OSCFunc({ ~printCheatSheet.value; }, '/hsc3/cheat').fix;
			// ---------------------------
		};,
			{ "hsc3: OSC Listener already installed".postln;})
    };
		{ "hsc3: SuperDirt already running, skipping init".postln; });
	)
    // --- Notify Emacs that SuperDirt and hsc3 are ready (Port 7777) ---
   s.sync;
   NetAddr("127.0.0.1", 7777).sendMsg("/dirt/ready", "SuperDirt is ready");
   "hsc3: SuperDirt is ready. Notifying Emacs on port 7777...".postln;
  };
)

(
if (~dirt.isNil, { "SuperDirt is not running".postln; }, { "SuperDirt already running".postln;})
)

(
~printCheatSheet = {
               "".postln;
               "--- hsc3 Sample Cheat Sheet ---".postln;
               [\bd, \sn, \cp, \hh, \arpy, \casio, \drum].do { |name|
                   if (~dirt.buffers[name].notNil) {
				       ("Sample '" ++ name ++ "' -> Buffer: " ++ ~dirt.buffers[name][0].bufnum).postln;
			       };
               };
               "-------------------------------".postln;
            }
)

(
if (~hsc3_oscFunc.isNil,
	{ ~hsc3_oscFunc = OSCFunc({ |msg|
                "hsc3: Syncing Server and SuperDirt...".postln;
                fork {
                    s.sendMsg("/d_loadDir", "/home/numa/.local/share/SuperCollider/synthdefs/");
                    s.sync;
                    SynthDescLib.global.read;
                    0.2.wait;
                    ~dirt.loadSynthDefs;
                    "hsc3: Sync complete. All definitions ready.".postln;
                    0.5.wait;
                    ~printCheatSheet.value;};
			}, '/hsc3/reload').fix;
	"hsc3: OSC Listener INSTALLED on port 57120".postln;},
	{ "hsc3: OSC Listener already installed".postln;})
)

~printCheatSheet.value;
/*

Sonification of rule90 CA
Ulrich Lehner, 2013W, DSP & Generative Music, Vienna University of Technology

Dependencies: Feedback (Quark)

------------------------------------------------------------------------------

Dieser Code sonfiziert einen 1D cellular automata, basierend auf Rule 90. Die
Ausgangskonfiguration wird rein zufällig bestimmt und kann mittels Parameter
konfiguriert werden. Die aktiven Zellen der aktuellen Generation des CAs werden
als Note interpretiert (major scale) und abgespielt. Pro Generation werden mehrere
Töne angespielt. Ein ADSR Envelop lässt die Noten sanft ausklingen. Um noch
mehr Variation einfließen zu lassen, wird auch die zeitliche Entwicklung be-
rücksichtig: die Summe der vergangenen aktiven Zellen (Wert "1") bestimmt die
Lautstärke und die "Raumgröße" (Reverb Filter). Tiefe Tonlagen deuten an, dass
aktive Zellen weiter links sind (Tonhöhe steigt nach rechts). Weitere Details
zur Synthese befinden sich in den Kommentaren im Code.

Für ein akkustisch spannenderes Ergebnis, wird noch ein kleiner Echo Effekt
angehängt (wird aber nicht weiter vom CA gesteuert). Dafür ist das "Feedback"
Quark notwendig. Die Installation kann über den Code ausgeführt werden, ggf.
ist das Paket auch im selben Ordner.

------------------------------------------------------------------------------

*/

s.boot;
s.freqscope;

Quarks.gui;
Quarks.install("Feedback");

(

/*****************************************/
/* COMPOSITION PARAMTER                  */
/*****************************************/

// Duration in seconds
~duration = 90;

// Pause between evolution cycle
~pause = 0.5;

// Number of cells for a generation
~fields = 30;

// Number of generation
~generations = 20;

// Probability that a cell is alive at init
~p_cell_alive = 0.1;

// Scale of the composition
~scale = Scale.major;

// Base MIDI note
~base_mini_note = 20;

/*****************************************/
/* DATA STRUCTURES                       */
/*****************************************/
~cells = Array.new;
~ca_synths = Array.new();

/*****************************************/
/* SYNTHS                                */
/*****************************************/

// Basic synth (inspired by http://www.youtube.com/watch?v=LKGGWsXyiyo)
SynthDef(\ca_synth, {
	arg freq = 440, amp = 0.5, a = 0.3, d = 0.1, s = 1.0, r = 2.0, gate = 0, mix = 0.8, room = 0, damp = 0.25;
	var sig, env;
	// Tiny modulutaion of the amp (slightly recognizable, this effect gets stronger with more alive cells in the past)
	amp = amp + (amp * LFPulse.kr(4) * 0.2);
	env = EnvGen.kr(Env.adsr(a, d, s, r), gate, doneAction: 0);
	sig = SinOsc.ar(freq, 0, amp);
	sig = sig * env;
	sig = FreeVerb.ar(sig, mix, room, damp) * amp;
	Out.ar(0, [sig, sig]);
}).add;

// Echo synth just for more fanciness
// Code from http://sccode.org/1-h
SynthDef(\echo,{|length = 1, fb = 0.8, sep = 0.012|
	var input = In.ar(0, 2);
	var output = input + Fb({

		arg feedback; // this will contain the delayed output from the Fb unit

		var left,right;
		var magic = LeakDC.ar(feedback*fb + input);
		magic = HPF.ar(magic, 400); // filter's on the feedback path
		magic = LPF.ar(magic, 5000);
		magic = magic.tanh; // and some more non-linearity in the form of distortion
		#left, right = magic; // let's have named variables for the left and right channels
		magic = [DelayC.ar(left, 1, LFNoise2.ar(12).range(0,sep)), DelayC.ar(right, 1, LFNoise2.ar(12).range(sep,0))]; // In addition to the main delay handled by the feedback quark, this adds separately modulated delays to the left and right channels, which with a small "sep" value creates a bit of spatialization

	}, length);
	ReplaceOut.ar(0, output);
}).add;

/*****************************************/
/* FUNCTIONS                             */
/*****************************************/

~init_cells = {
	var ic;
	~cells = Array.fill2D(~generations, ~fields, 0);
	ic = Array.new;
	~fields.do({
		ic = ic.add([0, 1].wchoose([1 - ~p_cell_alive, ~p_cell_alive]));
	});
	~cells[0] = ic;

	postln(ic);
};

// Fill synths
~init_synths = {
	~ca_synths = Array.new(~fields);
	~fields.do({
		arg idx;
		~ca_synths = ~ca_synths.add(Synth(\ca_synth, [\freq, ~scale.degreeToFreq(idx, ~base_mini_note.midicps, 1)]));
		postln("created ca_synth" + idx);
	});
	~echo_synth = Synth(\echo, [\length, 0, \fb, 0.7, \sep, 0.0012], addAction: \addToTail);
};

// Free synths
~free_synths = {
	~fields.do({
		arg idx;
		~ca_synths[idx].free;
		postln("destroyed ca_synth" + idx);
	});
	~echo_synth.free;
};

t = Task({
	~init_synths.();
	~init_cells.();
	// s.record;
	round(~duration / ~pause).do({
		~new_generation = Array.fill(~fields, 0);
		~current_generation = ~cells[0];
		~fields.do({
			arg idx;

			// Apply rule 90 (see http://mathworld.wolfram.com/Rule90.html)
			// Array borders circle
			var l_cell = (idx == 0).if({ ~current_generation[~fields - 1] }, { ~current_generation[idx - 1] });
			var r_cell = (idx == (~fields - 1)).if({ ~current_generation[0] }, { ~current_generation[idx + 1] });
			var c_cell = ~current_generation[idx];

			~new_generation[idx] = (
				( (l_cell == 1) && (c_cell == 1) && (r_cell == 0) ) ||
				( (l_cell == 1) && (c_cell == 0) && (r_cell == 0) ) ||
				( (l_cell == 0) && (c_cell == 1) && (r_cell == 1) ) ||
				( (l_cell == 0) && (c_cell == 0) && (r_cell == 1) )
			).if(1,0);
		});
		postln(~new_generation);

		// Shift generations (there's probably a better way to do this...)
		((~generations-1)..1).do({
			arg idx;
			~cells[idx] = ~cells[idx-1];
		});

		// Add newest generation at beginning
		~cells[0] = ~new_generation;

		// Play corresponding synths
		~fields.do({
			arg col;

			// Sum of past generations cells (excluding current cell)
			var sum = 0;
			(1..(~generations-1)).do({
				arg row;
				sum = sum + ~cells[row][col];
			});

			// Normalize sum
			sum = sum / ~generations;

			// Play sound
			~ca_synths[col].set(\gate, ~cells[0][col]);

			// Sum influences room (for reverb) and amp
			~ca_synths[col].set(\room, sum);
			~ca_synths[col].set(\amp, sum * 0.5);
		});

		~pause.wait;
	});

	~fields.do({
		arg idx;
		~ca_synths[idx].set(\gate, 0);
	});

	// Dirty wait to free synths
	5.wait;
	~free_synths.();
	// s.stopRecording;
});

t.start;

)

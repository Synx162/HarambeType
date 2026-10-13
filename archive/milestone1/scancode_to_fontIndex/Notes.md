Explanation of how scancode\_to\_fontIndex works



Signals



sc\_rdy = 1 for exactly one clock when a byte is valid on sc



y = current FSM state (updates on the posedge)



Y = next-state (combinational)



make\_cycle = (y==S\_BASE) \&\& sc\_rdy \&\& ~is\_F0 \&\& ~is\_E0



Timeline

Cycle	What’s on sc	sc\_rdy	y at start	Combinational Y becomes…	Strobe allowed? (make\_cycle)	On the next posedge y becomes…

N	F0	1	BASE	GOTF0 (because is\_F0)	0 (prefix)	GOTF0

N+1	1C	1	GOTF0	BASE (consume one byte)	0 (y!=BASE)	BASE

N+2	—	0	BASE	BASE	—	BASE



At cycle N: you’re still in BASE. Seeing F0 sets Y = GOTF0, but you don’t jump yet — that happens at the next clock edge.



At cycle N+1: you are now in GOTF0. The very next byte (1C) arrives with sc\_rdy=1.

Because y!=BASE, make\_cycle=0 → no output pulse. The next-state logic sets Y = BASE, i.e., we consume this one byte and go back.



At cycle N+2: you’re back in BASE, ready for normal bytes again.



That one cycle spent in GOTF0 is what “eats” (ignores) the byte after F0.

Same idea for extended-break: E0 → GOTE0, then F0 → GOTE0F0, then the next byte is consumed in GOTE0F0.



If you want to see it in your sim, add these to the wave:



y and Y



make\_cycle



inputChar\_rdy



You’ll see y: BASE→GOTF0→BASE, and no inputChar\_rdy when the post-F0 byte arrives because y==GOTF0 in that cycle.



-----------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------



***// =========================================================================***

    ***// STEP 1: Synchronize sc\_rdy to our clock domain***

    ***// =========================================================================***

    ***// The sc\_rdy signal comes from the PS/2 controller which may be in a***

    ***// different clock domain. We need to synchronize it safely to avoid***

    ***// metastability issues. // NOT DOING ANTMORE***



initially considered using a synchronizer, but after analyzing the PS/2 receiver code, I found that ps2\_rec is combinational logic derived from signals (Packet and Serial) that are already registered on CLOCK\_50 - the same clock my module uses. Since we're in the same clock domain, there's no clock domain crossing and therefore no metastability risk. My output register samples sc\_rdy on the clock edge after any combinational glitches have settled, which is sufficient for safe operation.



// =============================================================================

// DETAILED EXPLANATION SECTIONS

// =============================================================================



// NO SYNCHRONIZER NEEDED:

// ----------------------

// The ps2\_rec signal from ps2\_receiver.v is combinational logic derived from

// Packet and Serial, which are both registered on CLOCK\_50 (same clock as this

// module). Since we're in the same clock domain, there's no metastability risk.

// 

// Our output register samples sc\_rdy on the clock edge, after any combinational

// glitches have settled. This is sufficient for safe operation.



// STATE MACHINE:

// -------------

// PS/2 keyboard sends different types of scancodes:

// - MAKE code: Single byte when key pressed (e.g., 0x1C for 'A')

// - BREAK code: F0 followed by key code when released (e.g., F0 1C)

// - Extended codes: E0 followed by key code (e.g., E0 75 for up arrow)

// - Extended break: E0 F0 followed by key code

//

// We only want simple MAKE codes, so the FSM filters out everything else:

// - BASE state: Normal operation, waiting for keys

// - GOTF0 state: Just saw F0, next byte is a break code (ignore it)

// - GOTE0 state: Just saw E0, next is an extended code (ignore it)  

// - GOTE0F0 state: Saw E0 then F0, next is extended break (ignore it)



// FAST TYPING FIX:

// ---------------

// The decoder and FSM check 'sc' directly so that state transitions and 

// character decoding happen in the same cycle the data arrives. This prevents

// the FSM from getting out of sync when bytes arrive back-to-back during fast

// typing.



// REGISTERED OUTPUT:

// -----------------

// inputChar\_rdy is registered (not combinational) to ensure a clean, glitch-free

// signal that only changes on clock edges. This guarantees downstream modules

// can reliably sample it without timing issues.



// CHARACTER MAPPING:

// -----------------

// Mapping:

//   0-25  : letters a-z

//   26    : space

//   27-36 : digits 0-9

//   37-47 : punctuation (` - = \[ ] \\ ; ' , . /)

//   48    : backspace

//   49    : enter

//   FF    : invalid/unmapped key


graph LR

&nbsp; %% =========================

&nbsp; %% INPUT + KEYBOARD FRONT END

&nbsp; %% =========================

&nbsp; KB\[PS/2 Keyboard] --> RCV\[ps2\_receiver<br/>(20-cycle)]

&nbsp; RCV -->|sc\[7:0], sc\_rdy| SC2FONT\[scancode\_to\_fontIndex<br/>(MAKE-only, flags)]

&nbsp; SC2FONT -->|inputChar\[7:0], inputChar\_rdy| MAIN\[Main Controller<br/>(FSM + kb\_char\_reg)]



&nbsp; %% =========================

&nbsp; %% TARGET WORDS + PRELOAD

&nbsp; %% =========================

&nbsp; KEY1\[\[KEY\[1]]] --> TWORDS\[target\_words<br/>(40 words ROM)]

&nbsp; TWORDS -->|target chars| PRELOAD\_DRAW\[preload\_to\_pixel\_draw<br/>(top box)]



&nbsp; %% done\_list storage

&nbsp; MAIN -->|add\_char, char\_in\[4:0]| DONELIST\[done\_list<br/>(320×5-bit buffer)]

&nbsp; TWORDS -. optional path .-> DONELIST

&nbsp; DONELIST -->|words\_flat\[1599:0]| COMP\[comparator]



&nbsp; %% =========================

&nbsp; %% TIMER PATH

&nbsp; %% =========================

&nbsp; KEY2\[\[KEY\[2]]] --> TIMER\[countdown\_timer<br/>(15 → 0 s)]

&nbsp; TIMER -->|value\[3:0]| NUMDRAW\[counter\_to\_pixel\_draw<br/>(timer box)]



&nbsp; %% =========================

&nbsp; %% TYPED CHAR → COMPARATOR

&nbsp; %% =========================

&nbsp; MAIN -->|typed\_char\[4:0], typed\_char\_valid| COMP



&nbsp; COMP -->|char\_errors\[15:0]| LEDCHAR\[LEDR\[3:0]<br/>(char errors)]

&nbsp; COMP -->|word\_errors\[15:0]| LEDWORD\[LEDR\[9:7]<br/>(word errors)]



&nbsp; %% =========================

&nbsp; %% BOTTOM TEXT DRAWER (TYPING)

&nbsp; %% =========================

&nbsp; MAIN -->|cursor pos + kb\_char\_reg| CHARDRAW\[char\_to\_pixel\_draw<br/>(bottom box)]



&nbsp; %% =========================

&nbsp; %% CLEARING LOGIC

&nbsp; %% =========================

&nbsp; MAIN -->|clearing\_en, box select| CLEAR\[Clear logic<br/>(3-box pixel scan)]



&nbsp; %% =========================

&nbsp; %% 3-LEVEL ARBITER + VGA

&nbsp; %% =========================

&nbsp; subgraph TEXT\_PATH\[Text Path Mux (Level 2)]

&nbsp;   PRELOAD\_DRAW --> TEXMUX

&nbsp;   CHARDRAW --> TEXMUX

&nbsp; end



&nbsp; subgraph TOPMUX\[3-Level Arbiter]

&nbsp;   NUMDRAW --> TOPMUX

&nbsp;   TEXMUX --> TOPMUX

&nbsp;   CLEAR --> TOPMUX

&nbsp; end



&nbsp; TOPMUX --> VGA\[vga\_adapter]

&nbsp; VGA --> MON\[Monitor]






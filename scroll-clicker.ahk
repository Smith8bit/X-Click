#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"

; Hold a key and scroll: the cursor moves left/right and clicks at every
; fixed distance along the way. Settings change live from the window and
; are saved to scroll-clicker.ini next to this script.

INI := A_ScriptDir "\scroll-clicker.ini"

TRIGGER_NAMES := ["CapsLock", "ScrollLock", "Insert", "Mouse back button", "Mouse forward button"]
TRIGGER_KEYS  := ["CapsLock", "ScrollLock", "Insert", "XButton1", "XButton2"]
BUTTONS       := ["Left", "Right", "Middle"]

cfg := {}
cfg.enabled    := LoadSetting("enabled",    1,  0, 1)
cfg.trigger    := LoadSetting("trigger",    1,  1, TRIGGER_KEYS.Length)
cfg.spacing    := LoadSetting("spacing",    20, 5, 1000)
cfg.notch      := LoadSetting("notch",      60, 1, 2000)
cfg.button     := LoadSetting("button",     1,  1, BUTTONS.Length)
cfg.clickStart := LoadSetting("clickStart", 1,  0, 1)
cfg.reverse    := LoadSetting("reverse",    0,  0, 1)
cfg.onTop      := LoadSetting("onTop",      1,  0, 1)

; trigger: key currently bound, held: trigger is down, fresh: no notch yet in
; this hold, scrolled: wheel used in this hold, busy/pending: clicking and the
; notches still queued, anchorX: x where the click points start, offset: how
; far the cursor is from anchorX, clicks: clicks in this run
state := {trigger: "", held: false, fresh: false, scrolled: false, busy: false, pending: 0, anchorX: 0, offset: 0, clicks: 0}

; ---------- Settings window ----------
g := Gui((cfg.onTop ? "+AlwaysOnTop " : "") "-MaximizeBox", "Scroll Clicker")
g.SetFont("s9", "Segoe UI")
g.MarginX := 14, g.MarginY := 12

cbEnabled := g.Add("Checkbox", "xm Checked" cfg.enabled, "Enabled")

g.Add("Text", "xm y+14 w120", "Hold key:")
ddTrigger := g.Add("DropDownList", "x+4 yp-3 w150 Choose" cfg.trigger, TRIGGER_NAMES)

g.Add("Text", "xm y+10 w120", "Click every (px):")
edSpacing := g.Add("Edit", "x+4 yp-3 w70 Number")
g.Add("UpDown", "Range5-1000 0x80", cfg.spacing)

g.Add("Text", "xm y+10 w120", "Move per notch (px):")
edNotch := g.Add("Edit", "x+4 yp-3 w70 Number")
g.Add("UpDown", "Range1-2000 0x80", cfg.notch)

g.Add("Text", "xm y+10 w120", "Mouse button:")
ddButton := g.Add("DropDownList", "x+4 yp-3 w80 Choose" cfg.button, BUTTONS)

cbStart   := g.Add("Checkbox", "xm y+14 Checked" cfg.clickStart, "Click the starting point")
cbReverse := g.Add("Checkbox", "xm y+6 Checked" cfg.reverse, "Reverse scroll direction")
cbOnTop   := g.Add("Checkbox", "xm y+6 Checked" cfg.onTop, "Keep this window on top")

statusText := g.Add("Text", "xm y+14 w274 r2 cGray")

for ctl in [cbEnabled, cbStart, cbReverse, cbOnTop]
    ctl.OnEvent("Click", ReadGui)
for ctl in [ddTrigger, edSpacing, edNotch, ddButton]
    ctl.OnEvent("Change", ReadGui)
g.OnEvent("Close", (*) => ExitApp())

HotIf(TriggerHeld)   ; the wheel is only taken over while the trigger key is down
Hotkey("*WheelDown", (*) => OnWheel(+1), "T20")
Hotkey("*WheelUp", (*) => OnWheel(-1), "T20")
HotIf()

ApplyHotkeys()
ShowStatus()
g.Show()

; ---------- Settings ----------
LoadSetting(name, def, lo, hi) {
    v := IniRead(INI, "settings", name, def)
    return IsInteger(v) ? Max(lo, Min(Integer(v), hi)) : def
}

EditValue(ctl, old, lo, hi) {   ; ignore half-typed or out-of-range numbers
    v := ctl.Value
    return IsInteger(v) && v >= lo && v <= hi ? Integer(v) : old
}

ReadGui(*) {   ; runs on every change in the window, so settings apply right away
    cfg.enabled    := cbEnabled.Value
    cfg.trigger    := ddTrigger.Value
    cfg.spacing    := EditValue(edSpacing, cfg.spacing, 5, 1000)
    cfg.notch      := EditValue(edNotch, cfg.notch, 1, 2000)
    cfg.button     := ddButton.Value
    cfg.clickStart := cbStart.Value
    cfg.reverse    := cbReverse.Value
    cfg.onTop      := cbOnTop.Value
    g.Opt(cfg.onTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
    for name, value in cfg.OwnProps()
        IniWrite(value, INI, "settings", name)
    ApplyHotkeys()
    ShowStatus()
}

ShowStatus() {
    if !cfg.enabled
        statusText.Text := "Off. Scrolling works normally."
    else if state.held && state.scrolled
        statusText.Text := "Clicking: " state.clicks " clicks, " Abs(state.offset) " px from start"
    else
        statusText.Text := "Ready. Hold " TRIGGER_NAMES[cfg.trigger] " and scroll." . (state.clicks ? "`nLast run: " state.clicks " clicks" : "")
}

; ---------- Hotkeys ----------
; The trigger key's own press/release hotkeys track whether it's held. This
; also works for keys sent by software (remappers, mouse button apps), which
; GetKeyState's physical mode can't see.
ApplyHotkeys() {   ; bind the chosen key, or unbind it when turned off
    want := cfg.enabled ? TRIGGER_KEYS[cfg.trigger] : ""
    if want = state.trigger
        return
    if state.trigger != "" {
        Hotkey("*" state.trigger, "Off")
        Hotkey("*" state.trigger " Up", "Off")
    }
    if want != "" {
        Hotkey("*" want, TriggerDown, "On")
        Hotkey("*" want " Up", TriggerUp, "On")
    }
    state.trigger := want
    state.held := false
}

TriggerHeld(*) => state.held

TriggerDown(*) {
    if state.held          ; ignore key auto-repeat
        return
    state.held := true, state.fresh := true, state.scrolled := false, state.pending := 0
}

TriggerUp(*) {
    state.held := false
    if !state.scrolled     ; pressed alone: let the key do its normal job
        PassThrough(state.trigger)
    ShowStatus()
}

PassThrough(key) {   ; the key pressed alone (no scroll) still does its normal job
    if key = "CapsLock"
        SetCapsLockState(!GetKeyState("CapsLock", "T"))
    else if key = "ScrollLock"
        SetScrollLockState(!GetKeyState("ScrollLock", "T"))
    else
        Send "{" key "}"
}

OnWheel(dir) {   ; notches that arrive while clicking are queued, not dropped
    state.scrolled := true
    state.pending += cfg.reverse ? -dir : dir
    if state.busy
        return
    state.busy := true
    try {
        while state.pending != 0 && state.held {
            d := state.pending > 0 ? 1 : -1
            state.pending -= d
            Travel(d)
        }
    } finally {
        state.busy := false
    }
    ShowStatus()
}

Travel(dir) {
    step := cfg.spacing, btn := BUTTONS[cfg.button]
    MouseGetPos &x, &y
    if state.fresh {                      ; first notch since the key went down
        state.fresh := false
        state.anchorX := x, state.offset := 0, state.clicks := 0
        if cfg.clickStart
            DoClick(btn)
    }
    ; stay inside the screen (all monitors)
    left := SysGet(76), right := left + SysGet(78) - 1
    target := Max(left - state.anchorX, Min(state.offset + dir * cfg.notch, right - state.anchorX))

    ; visit and click every point between the old and new position
    pos := state.offset
    k := dir > 0 ? Floor(pos / step) + 1 : Ceil(pos / step) - 1
    while state.held && (dir > 0 ? k * step <= target : k * step >= target) {
        pos := k * step
        MouseMove state.anchorX + pos, y, 0
        DoClick(btn)
        k += dir
    }
    if state.held                         ; key let go mid-move: stop where we are
        pos := target
    state.offset := pos
    MouseMove state.anchorX + pos, y, 0
    ShowStatus()
}

DoClick(btn) {
    Click btn
    state.clicks += 1
}

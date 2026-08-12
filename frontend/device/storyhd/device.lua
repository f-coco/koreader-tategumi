-- iRiver Story HD (EB07) — KOReader 2026 nightly adaption
-- i.MX508 (Freescale MX50 RDP), ARMv7 Cortex-A8, 128MB RAM.
-- 6" E Ink Pearl @ 768x1024 (16bpp RGB565), NO touchscreen.
-- Keyboard: /dev/input/event0 (mxckpd). EPDC: Freescale MXCFB V1 (64B struct).
-- Keycodes (measured): 小键盘方向=37/38/39/40(WinVK), 五维=116/117/118/119,
--   HOME=112 BACK=113 ENTER=114 OPTION=115 SPACE=32 letters=ASCII(65-90)
local Generic = require("device/generic/device")
local logger = require("logger")

local function yes() return true end
local function no() return false end

local StoryHD = Generic:extend{
    model = "Story HD",
    isStoryHD = yes,
    -- hasDPad enables FocusManager keyboard navigation (Up/Down/Left/Right/Press)
    -- for menus & FileChooser, and routes FileManager menu to TouchMenu (avoids
    -- Menu.itemTableFromTouchMenu crashing on numeric tab keys).
    hasDPad = yes,
    hasKeys = yes,
    canKeyRepeat = yes,
    isTouchDevice = no,
    hasEinkScreen = yes,
    hasFrontlight = no,
    hasExitOptions = yes,
    canReboot = yes,
    canPowerOff = yes,
    canSuspend = no,
    hasWifiToggle = no,
    hasWifiManager = no,
    display_dpi = 213, -- 6" 768x1024 => ~213 dpi
    home_dir = "/mnt/MOVIFAT",
    supportsScreensaver = yes,
}

function StoryHD:init()
    -- Load shim first (RTLD_GLOBAL) so libkoreader-input.so can resolve the
    -- GLIBC_2.9 symbols (pipe2/timerfd_*) that system glibc 2.7 lacks.
    pcall(function()
        local ffi = require("ffi")
        ffi.load("libs/libkoreader-shim.so", true)
        local ok2 = pcall(function() return ffi.C.pipe2 end)
        print("SHIM_INJECT: pipe2_visible=" .. tostring(ok2))
    end)
    self.screen = require("ffi/framebuffer_mxcfb"):new{device = self, debug = logger.dbg}
    self.input = require("device/input"):new{
        device = self,
        event_map = {
            [37] = "Left",          -- 小键盘←
            [38] = "Up",            -- 小键盘↑ = 光标上 / 阅读器滚动
            [39] = "Right",         -- 小键盘→
            [40] = "Down",          -- 小键盘↓ = 光标下 / 阅读器滚动
            [87] = "Up",            -- W = 光标上
            [83] = "Down",          -- S = 光标下
            [65] = "Left",          -- A = 光标左
            [68] = "Right",         -- D = 光标右
            [116] = "Up",           -- 五维↑ (实测)
            [117] = "Down",         -- 五维↓ (实测)
            [118] = "Left",         -- 五维← (实测)
            [119] = "Right",        -- 五维→ (实测)
            [32] = " ",
            [112] = "Home",         -- HOME 键 (实测)
            [113] = "Back",         -- BACK 键 (实测)
            [114] = "Press",        -- ENTER = 确认键 (实测)
            [115] = "Menu",         -- OPTION = 菜单键 (实测)
            [66] = "B", [67] = "C", [69] = "E", [70] = "F",
            [71] = "G", [72] = "H", [73] = "I", [74] = "J",
            [75] = "K", [76] = "L", [77] = "M", [78] = "N",
            [79] = "O", [80] = "P", [81] = "Q", [82] = "R",
            [84] = "T", [85] = "U", [86] = "V", [88] = "X",
            [89] = "Y", [90] = "Z",
        },
    }
    self.input:open("/dev/input/event0") -- mxckpd keyboard
    self.input:open("fake_events")       -- usb plug/unplug & charging
    Generic.init(self)
end

function StoryHD:exit()
    -- Clear the EPD to white before handing control back to flow, so flow's
    -- (partial) repaint isn't polluted by KOReader's last frame. Otherwise the
    -- screen can look frozen/unresponsive after choosing Exit.
    pcall(function()
        local Blitbuffer = require("ffi/blitbuffer")
        local screen = self.screen
        if screen then
            local bb = screen.full_bb or screen.bb
            if bb then
                bb:fill(Blitbuffer.COLOR_WHITE)
                screen:refreshFull(0, 0, screen:getWidth(), screen:getHeight())
                -- Let the EPD settle before flow takes over the framebuffer
                os.execute("sleep 1")
            end
        end
    end)
    Generic.exit(self)
end


return StoryHD

-- Vertical text settings (tategumi fork).
-- Punctuation/typography mode for vertical-rl:
--   zh_s = Simplified Chinese (GB/T 15834), full-em punctuation, corner quotes
--   zh_t = Traditional Chinese,                full-em punctuation, corner quotes
--   ja   = Japanese (m-tky original JFM)       half-em compaction + glue
-- Maps to crengine's vert_punct_mode_t (see lvfntman.h).
local Event = require("ui/event")
local logger = require("logger")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local ReaderVertical = WidgetContainer:extend{
    name = "vertical",
    is_doc_only = true,
}

-- 0 = 简体中文, 1 = 繁体中文, 2 = 日本語 (matches crengine vert_punct_mode_t)
local MODE_INT = { zh_s = 0, zh_t = 1, ja = 2 }
local MODES = {
    { key = "zh_s", text = _("Simplified Chinese (GB/T)") },
    { key = "zh_t", text = _("Traditional Chinese") },
    { key = "ja",   text = _("Japanese (original JFM)") },
}

function ReaderVertical:init()
    self.ui.menu:registerToMainMenu(self)
end

function ReaderVertical:onReadSettings(config)
    self.vert_punct_mode = config:readSetting("vert_punct_mode") or "zh_s"
    self.guji_page_border = config:readSetting("vert.page.border") or 0
    self.guji_column_rule = config:readSetting("vert.column.rule") or 0
    self:_apply()
end

function ReaderVertical:onSaveSettings()
    self.ui.doc_settings:saveSetting("vert_punct_mode", self.vert_punct_mode)
    self.ui.doc_settings:saveSetting("vert.page.border", self.guji_page_border or 0)
    self.ui.doc_settings:saveSetting("vert.column.rule", self.guji_column_rule or 0)
end

function ReaderVertical:_apply()
    if self.ui.document and self.ui.document.setVertPunctMode then
        self.ui.document:setVertPunctMode(MODE_INT[self.vert_punct_mode] or 0)
        if self.ui.document.setVertPageBorder then
            self.ui.document:setVertPageBorder(self.guji_page_border or 0)
            self.ui.document:setVertColumnRule(self.guji_column_rule or 0)
        end
    end
end

function ReaderVertical:onSetVertPunctMode(mode)
    self.vert_punct_mode = mode
    self:_apply()
    self.ui.doc_settings:saveSetting("vert_punct_mode", self.vert_punct_mode)
    self.ui:handleEvent(Event:new("UpdatePos"))
    logger.dbg("ReaderVertical: punct mode set to", mode)
    return true
end

local GUJI_WIDTHS = {
    { 0, _("关") }, { 1, _("细") }, { 2, _("中") }, { 3, _("粗") },
}

function ReaderVertical:onSetGuji(setting, value)
    self[setting] = value
    self:_apply()
    self.ui.doc_settings:saveSetting(setting == "guji_page_border" and "vert.page.border" or "vert.column.rule", value)
    self.ui:handleEvent(Event:new("UpdatePos"))
    logger.dbg("ReaderVertical: guji", setting, "set to", value)
    return true
end

function ReaderVertical:addToMainMenu(menu_items)
    local punct_mode_table = {}
    for _, m in ipairs(MODES) do
        table.insert(punct_mode_table, {
            text = m.text,
            radio = true,
            checked_func = function()
                return self.vert_punct_mode == m.key
            end,
            callback = function()
                self:onSetVertPunctMode(m.key)
            end,
        })
    end
    local function width_submenu(setting)
        local t = {}
        for _, w in ipairs(GUJI_WIDTHS) do
            table.insert(t, {
                text = w[2],
                radio = true,
                checked_func = function()
                    return (self[setting] or 0) == w[1]
                end,
                callback = function()
                    self:onSetGuji(setting, w[1])
                end,
            })
        end
        return t
    end
    local guji_table = {
        {
            text = _("页边框（回字框）"),
            sub_item_table = width_submenu("guji_page_border"),
        },
        {
            text = _("界行（列间竖线）"),
            sub_item_table = width_submenu("guji_column_rule"),
        },
    }
    menu_items.vertical_text = {
        text = _("Vertical text"),
        sub_item_table = {
            {
                text = _("Punctuation mode"),
                sub_item_table = punct_mode_table,
            },
            {
                text = _("古籍模式"),
                sub_item_table = guji_table,
            },
        },
    }
end

return ReaderVertical

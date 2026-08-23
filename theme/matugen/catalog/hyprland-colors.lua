-- >>> yutashell-matugen >>> (generated — edits will be overwritten)
-- Palette reference + compositor application in one file.
-- At Hyprland boot this runs when hyprland.lua requires it (Helmsman
-- exposes the `hl` table); live updates come from yutashell's post
-- hook running the same hl.config after every regeneration.
local C = {
    image = "{{image}}",
<* for name, value in colors *>
    {{name}} = "0xff{{value.default.hex_stripped}}",
<* endfor *>
}

if hl ~= nil and hl.config ~= nil then
    hl.config({
        general = {
            col = {
                active_border = C.primary,
                inactive_border = C.outline_variant,
            },
        },
        group = {
            col = {
                border_active = C.primary,
                border_inactive = C.outline_variant,
            },
            groupbar = {
                col = {
                    active = C.on_primary_container,
                    inactive = C.outline_variant,
                },
            },
        },
    })
end

return C

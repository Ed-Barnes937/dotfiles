local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- Rosé Pine in both polarities: Moon when macOS is dark, Dawn when it is light.
-- Everything that depends on which way round the palette is lives in here.
-- Opacity has to flip too: the near-transparent window that reads as moody over
-- a dark desktop just looks washed out over a light one. So does the unfocused
-- dim, and in the opposite direction - Dawn is dark text on a light ground, so
-- fading it means pushing brightness *up* toward the background, not down.
local APPEARANCES = {
	Dark = {
		color_scheme = "rose-pine-moon",
		claude_theme = "moon",
		window_background_opacity = 0.8,
		unfocused_window_background_opacity = 0.62,
		unfocused_foreground_text_hsb = { hue = 1.0, saturation = 0.25, brightness = 0.45 },
	},
	Light = {
		color_scheme = "rose-pine-dawn",
		claude_theme = "dawn",
		window_background_opacity = 0.92,
		unfocused_window_background_opacity = 0.8,
		unfocused_foreground_text_hsb = { hue = 1.0, saturation = 0.25, brightness = 2.0 },
	},
}

-- Appearance also comes through as the high-contrast variants
-- ("DarkHighContrast"), and as nil wherever there is no gui to ask.
local function appearance_settings(appearance)
	if appearance ~= nil and appearance:find("Light") then
		return APPEARANCES.Light
	end
	return APPEARANCES.Dark
end

-- wezterm.gui is absent outside the gui process (the mux server, `wezterm cli`),
-- and get_appearance() errors rather than returning when called off the gui
-- thread. Either way the config still has to evaluate, so fall back to dark.
local function system_appearance()
	if wezterm.gui == nil then
		return nil
	end
	local ok, appearance = pcall(wezterm.gui.get_appearance)
	if not ok then
		return nil
	end
	return appearance
end

-- Claude Code will follow the OS or use a custom palette, never both: its
-- "theme" setting is either "auto" or a "custom:<slug>" that pins one base. So
-- the setting stays fixed at custom:active and we swap what active.json *is*.
-- Claude watches its themes directory and re-resolves the palette from the
-- file's "base", so this repaints a running session. The indirection is to keep
-- the write off ~/.claude/settings.json, which resolves into the dotfiles repo
-- and would read as a dirty tree after every sunset.
local CLAUDE_THEMES = wezterm.home_dir .. "/.claude/themes"
local CLAUDE_THEME_SOURCES = wezterm.home_dir .. "/.claude/theme-sources"

local function shell_quote(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function sync_claude_theme(name)
	local source = CLAUDE_THEME_SOURCES .. "/" .. name .. ".json"
	local active = CLAUDE_THEMES .. "/active.json"
	-- Stage in the same directory and rename, so the watcher never sees a
	-- half-written file. Claude would only log that one as invalid JSON and keep
	-- the previous palette, but a torn read is still a reload wasted.
	wezterm.background_child_process({
		"/bin/sh",
		"-c",
		table.concat({
			"mkdir -p " .. shell_quote(CLAUDE_THEMES),
			"cp " .. shell_quote(source) .. " " .. shell_quote(active .. ".tmp"),
			"mv " .. shell_quote(active .. ".tmp") .. " " .. shell_quote(active),
		}, " && "),
	})
end

-- wezterm re-reads this file when the macOS appearance changes, so assigning
-- from it at config scope is the whole switching mechanism. No watcher process.
local detected_appearance = system_appearance()
local appearance = appearance_settings(detected_appearance)
config.color_scheme = appearance.color_scheme
config.window_background_opacity = appearance.window_background_opacity

-- Only the gui process can see the real appearance. The mux server reports nil
-- and falls back to Dark above, which is harmless for its own colours but would
-- stamp the wrong half of the switch over a correct active.json.
if detected_appearance ~= nil then
	sync_claude_theme(appearance.claude_theme)
end

config.font = wezterm.font("Monaspace Argon")
config.font_size = 14
config.macos_window_background_blur = 40
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Deliberately leaving enable_kitty_keyboard off. Claude Code requests kitty
-- flags 5 at TUI startup (ESC [ <u then ESC [ >5u), and when wezterm honours
-- that request Escape stops cancelling an in-progress run. There is no per-app
-- gating in wezterm and no Claude-side opt-out, so nvim's unambiguous
-- modifier+key reporting is not worth losing escape-to-cancel.

config.keys = {
	{
		key = "LeftArrow",
		mods = "OPT",
		action = wezterm.action.SendString "\x1bb"
	},
	{
		key = "RightArrow",
		mods = "OPT",
		action = wezterm.action.SendString "\x1bf"
	},
	{
		key = "Backspace",
		mods = "CMD",
		-- Ctrl-U: zsh's kill-whole-line
		action = wezterm.action.SendString "\x15"
	}
}

-- get_config_overrides() hands back a copy, so the current value is never the
-- same table we last stored; compare the fields instead of the identity.
local function same_text_hsb(actual, expected)
	if actual == nil or expected == nil then
		return actual == expected
	end
	return actual.hue == expected.hue
		and actual.saturation == expected.saturation
		and actual.brightness == expected.brightness
end

-- Dim unfocused windows so the focused one is obvious at a glance. A focused
-- window owns neither value, so clearing them falls back to the config above,
-- which is already the right way round for the current appearance.
local function apply_window_overrides(window)
	local settings = appearance_settings(window:get_appearance())
	local overrides = window:get_config_overrides() or {}
	local text_hsb, opacity
	if not window:is_focused() then
		text_hsb = settings.unfocused_foreground_text_hsb
		opacity = settings.unfocused_window_background_opacity
	end

	-- Only write when one of the two values we own actually changes; a redundant
	-- set_config_overrides() call would trigger another config reload.
	if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
		return
	end

	overrides.foreground_text_hsb = text_hsb
	overrides.window_background_opacity = opacity
	window:set_config_overrides(overrides)
end

wezterm.on("window-focus-changed", apply_window_overrides)
-- Also on reload, which is how an appearance change arrives: a window that was
-- unfocused when the system flipped would otherwise keep yesterday's dim until
-- it next gained focus. The guard above is what keeps this from recursing on
-- the reload that set_config_overrides() itself triggers.
wezterm.on("window-config-reloaded", apply_window_overrides)

return config

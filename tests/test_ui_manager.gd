## Unit tests for SKUIManager.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## Tests cover menu registration, open/close, stack behavior, HUD show/hide,
## and overlay layer management.  All tests use in-process Control stubs so
## no real scene or GameInfo connection is needed.
extends GutTest


# ── Helpers ───────────────────────────────────────────────────────────────


## Minimal UIManager with GameInfo.pause_game replaced by a flag so the test
## doesn't need the full autoload graph.
class _TestUIManager extends SKUIManager:
	var _game_paused: bool = false
	var _game_mouse_visible: bool = false

	func _enter_menu_mode() -> void:
		_game_paused = true
		_game_mouse_visible = true

	func _exit_menu_mode() -> void:
		_game_paused = false
		_game_mouse_visible = false


func _make_manager() -> _TestUIManager:
	var mgr := _TestUIManager.new()
	add_child_autofree(mgr)
	return mgr


func _make_control(control_name: String = "TestMenu") -> Control:
	var c := Control.new()
	c.name = control_name
	return c


# ── Registration ──────────────────────────────────────────────────────────


func test_register_menu_makes_it_available() -> void:
	var mgr := _make_manager()
	var menu := _make_control("Inventory")
	mgr.register_menu(&"Inventory", menu)
	assert_false(menu.visible, "Freshly registered menu must be hidden.")


func test_register_multiple_menus() -> void:
	var mgr := _make_manager()
	var m1 := _make_control("Menu1")
	var m2 := _make_control("Menu2")
	mgr.register_menu(&"Menu1", m1)
	mgr.register_menu(&"Menu2", m2)
	assert_false(m1.visible)
	assert_false(m2.visible)


# ── Open / Close ──────────────────────────────────────────────────────────


func test_open_menu_makes_it_visible() -> void:
	var mgr := _make_manager()
	var menu := _make_control()
	mgr.register_menu(&"TestMenu", menu)
	mgr.open_menu(&"TestMenu")
	assert_true(menu.visible)


func test_close_menu_hides_it() -> void:
	var mgr := _make_manager()
	var menu := _make_control()
	mgr.register_menu(&"TestMenu", menu)
	mgr.open_menu(&"TestMenu")
	mgr.close_menu(&"TestMenu")
	assert_false(menu.visible)


func test_open_unregistered_menu_does_not_crash() -> void:
	var mgr := _make_manager()
	# Should push a warning but not throw
	mgr.open_menu(&"DoesNotExist")
	assert_false(mgr.is_menu_open())


func test_close_unregistered_menu_does_not_crash() -> void:
	var mgr := _make_manager()
	mgr.close_menu(&"DoesNotExist")
	assert_false(mgr.is_menu_open())


func test_open_already_open_menu_is_idempotent() -> void:
	var mgr := _make_manager()
	var menu := _make_control()
	mgr.register_menu(&"TestMenu", menu)
	mgr.open_menu(&"TestMenu")
	mgr.open_menu(&"TestMenu")  # second call — no duplicate push
	mgr.close_menu(&"TestMenu")
	# Stack should now be empty
	assert_false(mgr.is_menu_open())


# ── Stack behavior ────────────────────────────────────────────────────────


func test_is_menu_open_false_when_empty() -> void:
	var mgr := _make_manager()
	assert_false(mgr.is_menu_open())


func test_is_menu_open_true_after_opening() -> void:
	var mgr := _make_manager()
	var menu := _make_control()
	mgr.register_menu(&"A", menu)
	mgr.open_menu(&"A")
	assert_true(mgr.is_menu_open())


func test_is_menu_open_false_after_all_closed() -> void:
	var mgr := _make_manager()
	var m1 := _make_control("A")
	var m2 := _make_control("B")
	mgr.register_menu(&"A", m1)
	mgr.register_menu(&"B", m2)
	mgr.open_menu(&"A")
	mgr.open_menu(&"B")
	mgr.close_menu(&"A")
	mgr.close_menu(&"B")
	assert_false(mgr.is_menu_open())


func test_close_top_menu_closes_most_recent() -> void:
	var mgr := _make_manager()
	var m1 := _make_control("A")
	var m2 := _make_control("B")
	mgr.register_menu(&"A", m1)
	mgr.register_menu(&"B", m2)
	mgr.open_menu(&"A")
	mgr.open_menu(&"B")
	mgr.close_top_menu()
	assert_false(m2.visible, "Top menu (B) must be hidden.")
	assert_true(m1.visible, "Lower menu (A) must remain open.")


func test_close_all_menus_clears_stack() -> void:
	var mgr := _make_manager()
	var m1 := _make_control("A")
	var m2 := _make_control("B")
	mgr.register_menu(&"A", m1)
	mgr.register_menu(&"B", m2)
	mgr.open_menu(&"A")
	mgr.open_menu(&"B")
	mgr.close_all_menus()
	assert_false(mgr.is_menu_open())
	assert_false(m1.visible)
	assert_false(m2.visible)


# ── Pause integration ─────────────────────────────────────────────────────


func test_opening_first_menu_enters_menu_mode() -> void:
	var mgr := _make_manager()
	var menu := _make_control()
	mgr.register_menu(&"M", menu)
	mgr.open_menu(&"M")
	assert_true(mgr._game_paused, "Opening the first menu must pause the game.")


func test_closing_last_menu_exits_menu_mode() -> void:
	var mgr := _make_manager()
	var menu := _make_control()
	mgr.register_menu(&"M", menu)
	mgr.open_menu(&"M")
	mgr.close_menu(&"M")
	assert_false(mgr._game_paused, "Closing the last menu must unpause.")


func test_opening_second_menu_does_not_double_pause() -> void:
	var mgr := _make_manager()
	var m1 := _make_control("A")
	var m2 := _make_control("B")
	mgr.register_menu(&"A", m1)
	mgr.register_menu(&"B", m2)
	mgr.open_menu(&"A")
	assert_true(mgr._game_paused)
	mgr.open_menu(&"B")
	# Still paused — no double transition
	assert_true(mgr._game_paused)


func test_closing_one_of_two_menus_keeps_paused() -> void:
	var mgr := _make_manager()
	var m1 := _make_control("A")
	var m2 := _make_control("B")
	mgr.register_menu(&"A", m1)
	mgr.register_menu(&"B", m2)
	mgr.open_menu(&"A")
	mgr.open_menu(&"B")
	mgr.close_menu(&"B")
	assert_true(mgr._game_paused, "Game should remain paused while A is still open.")


# ── HUD ───────────────────────────────────────────────────────────────────


func test_set_hud_makes_hud_visible() -> void:
	var mgr := _make_manager()
	var hud := SKHUDShell.new()
	mgr.set_hud(hud)
	assert_not_null(mgr._hud)


func test_show_and_hide_hud() -> void:
	var mgr := _make_manager()
	var hud := SKHUDShell.new()
	mgr.set_hud(hud)
	mgr.hide_hud()
	assert_false(hud.visible)
	mgr.show_hud()
	assert_true(hud.visible)


# ── Signals ───────────────────────────────────────────────────────────────


func test_menu_opened_signal_emitted() -> void:
	var mgr := _make_manager()
	var menu := _make_control()
	mgr.register_menu(&"Sig", menu)
	watch_signals(mgr)
	mgr.open_menu(&"Sig")
	assert_signal_emitted(mgr, "menu_opened")


func test_menu_closed_signal_emitted() -> void:
	var mgr := _make_manager()
	var menu := _make_control()
	mgr.register_menu(&"Sig", menu)
	mgr.open_menu(&"Sig")
	watch_signals(mgr)
	mgr.close_menu(&"Sig")
	assert_signal_emitted(mgr, "menu_closed")


func test_hud_shown_signal_emitted() -> void:
	var mgr := _make_manager()
	var hud := SKHUDShell.new()
	mgr.set_hud(hud)
	watch_signals(mgr)
	mgr.show_hud()
	assert_signal_emitted(mgr, "hud_shown")


func test_hud_hidden_signal_emitted() -> void:
	var mgr := _make_manager()
	var hud := SKHUDShell.new()
	mgr.set_hud(hud)
	mgr.show_hud()
	watch_signals(mgr)
	mgr.hide_hud()
	assert_signal_emitted(mgr, "hud_hidden")

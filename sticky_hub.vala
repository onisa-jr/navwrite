/*
 * NavWrite - Fast, floating, distraction-free scratchpad for Linux.
 *
 * Compilation:
 *   valac --pkg gtk+-3.0 sticky_hub.vala -X -lm -o navwrite
 */

using Gtk;
using Gdk;

// ============================================================================
// Model: Note Item
// ============================================================================

public class NoteItem : GLib.Object {
    public string name { get; set; }
    public int64 mtime { get; set; }

    public NoteItem(string name, int64 mtime) {
        this.name = name;
        this.mtime = mtime;
    }
}

// ============================================================================
// Main Application Class: StickyApp
// ============================================================================

public class StickyApp : GLib.Object {
    // GTK Application & Top-Level Windows
    private Gtk.Application app;
    private Gtk.Window hub_window;
    private Gtk.Window? menu_window = null;
    private Gtk.Window? editor_window = null;
    private StatusIcon tray_icon;

    // Storage & State
    private string notes_dir;
    private string? editing_note_title = null;
    private Entry title_entry;
    private TextView text_view;

    // Layout & Geometry
    private int hub_x = 100;
    private int hub_y = 100;
    private int circle_size = 56;
    private int gap = 15;

    // Visual Animation
    private double pulse_alpha = 1.0;
    private double pulse_scale = 1.0;
    private RGBA accent_green_rgba;

    // ------------------------------------------------------------------------
    // Initialization & Lifecycle
    // ------------------------------------------------------------------------

    public StickyApp() {
        accent_green_rgba = RGBA();
        accent_green_rgba.parse("#2ecc71");

        // Prefer Dropbox directory for cloud sync if available
        string dropbox_path = Path.build_filename(Environment.get_home_dir(), "Dropbox");
        if (FileUtils.test(dropbox_path, FileTest.EXISTS | FileTest.IS_DIR)) {
            notes_dir = Path.build_filename(dropbox_path, "StickyNotes");
        } else {
            notes_dir = Path.build_filename(Environment.get_home_dir(), "StickyNotes");
        }
        DirUtils.create_with_parents(notes_dir, 0755);

        // Strict single-instance configuration
        app = new Gtk.Application("com.navwrite.stickybubble", ApplicationFlags.DEFAULT_FLAGS);
        app.startup.connect(on_startup);
        app.activate.connect(on_activate);
    }

    private void on_startup() {
        app.hold();
        init_styles();
        create_hub();
        setup_tray_icon();
    }

    private void on_activate() {
        // When launched again while already running, raise the existing hub
        if (hub_window != null) {
            if (!hub_window.get_visible()) {
                hub_window.show_all();
            }
            hub_window.present();
            if (menu_window != null) {
                menu_window.show_all();
                menu_window.present();
            }
            if (editor_window != null) {
                editor_window.show_all();
                editor_window.present();
            }
        }
    }

    public int run(string[] args) {
        return app.run(args);
    }

    // ------------------------------------------------------------------------
    // UI Theming
    // ------------------------------------------------------------------------

    private void init_styles() {
        var provider = new CssProvider();
        string css = """
            .sticky-card { 
                background-color: #1a1a1a; 
                border-radius: 14px; 
                border: 1px solid rgba(255, 255, 255, 0.09); 
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.65); 
            }
            .note-row { 
                border-radius: 8px; 
                transition: background-color 150ms ease;
            }
            .note-row:hover { 
                background-color: rgba(255, 255, 255, 0.07); 
            }
            .note-label { 
                color: #e0e0e0; 
                font-weight: 600; 
                font-size: 10pt; 
            }
            .note-row:hover .note-label {
                color: #ffffff;
            }
            .add-row {
                border-radius: 8px;
                background-color: rgba(46, 204, 113, 0.08);
                transition: background-color 150ms ease;
                margin-top: 4px;
            }
            .add-row:hover {
                background-color: rgba(46, 204, 113, 0.20);
            }
            .add-label { 
                color: #2ecc71; 
                font-weight: bold; 
                font-size: 10pt; 
            }
            .confirm-label { 
                color: #ff5252; 
                font-weight: bold; 
                font-size: 9pt; 
            }
            .dim-label { 
                color: #666666; 
                font-size: 10pt;
                transition: color 150ms ease;
            }
            .note-row:hover .dim-label {
                color: #999999;
            }
            .dim-label:hover { 
                color: #ff5252; 
            }
            .confirm-btn-yes {
                background: #e74c3c;
                color: #ffffff;
                border-radius: 6px;
                font-size: 8pt;
                font-weight: bold;
                border: none;
            }
            .confirm-btn-no {
                background: #333333;
                color: #cccccc;
                border-radius: 6px;
                font-size: 8pt;
                font-weight: bold;
                border: none;
            }
            .editor-window { 
                background-color: #1a1a1a; 
                border-radius: 14px; 
                border: 1px solid rgba(255, 255, 255, 0.09); 
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.65); 
            }
            .editor-header {
                border-bottom: 1px solid rgba(255, 255, 255, 0.07);
                padding-bottom: 6px;
                margin-bottom: 8px;
            }
            entry { 
                background: none; 
                border: none; 
                color: #ffffff; 
                font-weight: bold; 
                font-size: 12pt; 
                box-shadow: none; 
                padding: 2px 0;
            }
            textview, textview text { 
                background-color: transparent; 
                color: #e6e6e6; 
                font-size: 11pt; 
                line-height: 1.5;
            }
            entry:focus, textview:focus { 
                border: none; 
                box-shadow: none; 
                outline: none; 
            }
            /* Eliminate all visible scrollbars */
            scrollbar,
            scrollbar *,
            scrollbar slider,
            scrollbar trough { 
                min-width: 0px; 
                min-height: 0px; 
                width: 0px; 
                height: 0px; 
                opacity: 0; 
                margin: 0px; 
                padding: 0px; 
                border: none; 
                background: transparent; 
                -GtkScrollbar-has-backward-stepper: false;
                -GtkScrollbar-has-forward-stepper: false;
            }
        """;
        try {
            provider.load_from_data(css, -1);
            StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(), 
                provider, 
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        } catch (Error e) {
            stderr.printf("CSS Error: %s\n", e.message);
        }
    }

    // ------------------------------------------------------------------------
    // Floating Hub Widget
    // ------------------------------------------------------------------------

    private void create_hub() {
        hub_window = new Gtk.Window();
        hub_window.set_type_hint(WindowTypeHint.DOCK);
        hub_window.set_keep_above(true);
        hub_window.set_decorated(false);
        hub_window.set_app_paintable(true);
        hub_window.set_visual(hub_window.get_screen().get_rgba_visual());
        hub_window.set_default_size(circle_size, circle_size);

        var drawing_area = new DrawingArea();
        drawing_area.draw.connect((ctx) => {
            // Pulsing outer diode circle
            ctx.set_source_rgba(accent_green_rgba.red, accent_green_rgba.green, accent_green_rgba.blue, pulse_alpha);
            double r = (circle_size / 2.0 - 6.0) * pulse_scale;
            ctx.arc(circle_size / 2.0, circle_size / 2.0, r, 0, 2 * Math.PI);
            ctx.fill();

            // Inner core dot
            ctx.set_source_rgba(accent_green_rgba.red * 0.5, accent_green_rgba.green * 0.5, accent_green_rgba.blue * 0.5, 0.8);
            ctx.arc(circle_size / 2.0, circle_size / 2.0, 8.0, 0, 2 * Math.PI);
            ctx.fill();
            return true;
        });

        hub_window.add_tick_callback((w, clock) => {
            double time = clock.get_frame_time() / 1000000.0;
            pulse_alpha = 0.7 + 0.3 * Math.sin(time * 0.5);
            pulse_scale = 1.0 + 0.05 * Math.sin(time * 0.5);
            drawing_area.queue_draw();
            return true;
        });

        hub_window.add(drawing_area);
        hub_window.add_events(EventMask.BUTTON_PRESS_MASK | EventMask.BUTTON_RELEASE_MASK | EventMask.BUTTON1_MOTION_MASK);

        int start_x = 0;
        int start_y = 0;
        bool is_dragging = false;

        hub_window.button_press_event.connect((event) => {
            if (event.button == 1) {
                start_x = (int)event.x;
                start_y = (int)event.y;
                is_dragging = false;
            }
            return true;
        });

        hub_window.motion_notify_event.connect((event) => {
            int x, y;
            hub_window.get_position(out x, out y);
            hub_window.move(x + (int)event.x - start_x, y + (int)event.y - start_y);
            is_dragging = true;
            refresh_child_positions();
            return true;
        });

        hub_window.button_release_event.connect((event) => {
            if (!is_dragging) {
                on_hub_clicked();
            }
            return true;
        });

        hub_window.move(hub_x, hub_y);
        hub_window.show_all();
        app.add_window(hub_window);
    }

    // ------------------------------------------------------------------------
    // Geometry & Dynamic Placement Engine
    // ------------------------------------------------------------------------

    private void refresh_child_positions() {
        int tx, ty, mw, mh;
        if (menu_window != null) {
            menu_window.get_size(out mw, out mh);
            get_best_pos(mw, mh, out tx, out ty);
            menu_window.move(tx, ty);
        }
        if (editor_window != null) {
            editor_window.get_size(out mw, out mh);
            get_best_pos(mw, mh, out tx, out ty);
            editor_window.move(tx, ty);
        }
    }

    private void get_best_pos(int win_w, int win_h, out int target_x, out int target_y) {
        int hx, hy;
        hub_window.get_position(out hx, out hy);
        Gdk.Display display = Gdk.Display.get_default();
        Gdk.Monitor monitor = display.get_monitor_at_window(hub_window.get_window());
        Gdk.Rectangle geo = monitor.get_geometry();

        target_y = hy - 15;

        if (hx + (circle_size / 2) > geo.x + (geo.width / 2)) {
            target_x = hx - win_w - gap;
        } else {
            target_x = hx + circle_size + gap;
        }

        if (target_y + win_h > geo.y + geo.height - 10) target_y = geo.y + geo.height - win_h - 10;
        if (target_x < geo.x + 10) target_x = geo.x + 10;
        if (target_x + win_w > geo.x + geo.width - 10) target_x = geo.x + geo.width - win_w - 10;
    }

    // ------------------------------------------------------------------------
    // Notes Menu (List & Selection)
    // ------------------------------------------------------------------------

    private void on_hub_clicked() {
        // If the note pad is open, dismiss and save it, then reverse back to the titles list
        if (editor_window != null) {
            force_close_editor();
            show_menu();
            return;
        }

        // If the titles list is already open, close it
        if (menu_window != null) {
            close_menu();
            return;
        }

        // Neither is open: reveal the titles list
        show_menu();
    }

    private void close_menu() {
        if (menu_window != null) {
            menu_window.destroy();
            menu_window = null;
        }
    }

    private void show_menu() {
        force_close_editor();
        close_menu();

        menu_window = new Gtk.Window();
        menu_window.get_style_context().add_class("sticky-card");
        menu_window.set_type_hint(WindowTypeHint.UTILITY);
        menu_window.set_decorated(false);
        menu_window.set_keep_above(true);
        menu_window.set_skip_taskbar_hint(true);

        var outer_box = new Box(Orientation.VERTICAL, 4);
        outer_box.set_border_width(8);

        var scroll = new ScrolledWindow(null, null);
        scroll.set_policy(PolicyType.NEVER, PolicyType.EXTERNAL);
        scroll.set_shadow_type(ShadowType.NONE);
        scroll.set_propagate_natural_height(true);
        scroll.set_propagate_natural_width(true);
        scroll.set_max_content_height(420);

        var notes_box = new Box(Orientation.VERTICAL, 3);
        var notes_list = new GLib.List<NoteItem>();

        try {
            var directory = File.new_for_path(notes_dir);
            var enumerator = directory.enumerate_children("standard::name,time::modified", FileQueryInfoFlags.NONE);
            FileInfo info;
            while ((info = enumerator.next_file()) != null) {
                string name = info.get_name();
                if (name.has_suffix(".txt")) {
                    var dt = info.get_modification_date_time();
                    int64 mtime = (dt != null) ? dt.to_unix() : 0;
                    notes_list.append(new NoteItem(name.replace(".txt", ""), mtime));
                }
            }
        } catch (Error e) {}

        // Sort: Most recently modified first, with alphabetical tie-breaking
        notes_list.sort((a, b) => {
            if (b.mtime > a.mtime) return 1;
            if (b.mtime < a.mtime) return -1;
            return a.name.collate(b.name);
        });

        foreach (var note in notes_list) {
            notes_box.add(create_branch_item(note.name, false));
        }

        scroll.add(notes_box);
        outer_box.pack_start(scroll, true, true, 0);
        outer_box.pack_end(create_branch_item("+ New Note", true), false, false, 0);

        menu_window.add(outer_box);

        // Automatic cursor scrolling: smooth auto-scroll when hovering near top/bottom edges
        var vadj = scroll.get_vadjustment();
        menu_window.add_tick_callback((w, clock) => {
            if (menu_window == null) return false;

            var pointer = Gdk.Display.get_default().get_default_seat().get_pointer();
            int rx, ry;
            pointer.get_position(null, out rx, out ry);

            int wx, wy, ww, wh;
            menu_window.get_position(out wx, out wy);
            menu_window.get_size(out ww, out wh);

            if (rx >= wx && rx <= wx + ww && ry >= wy && ry <= wy + wh) {
                double win_y = ry - wy;
                double zone = 75.0;
                double velocity = 0.0;

                if (win_y < zone) {
                    double factor = (zone - win_y) / zone;
                    velocity = -2.0 - factor * 8.0;
                } else if (win_y > wh - zone) {
                    double factor = (win_y - (wh - zone)) / zone;
                    velocity = 2.0 + factor * 8.0;
                }

                if (velocity != 0.0) {
                    double cur = vadj.get_value();
                    double max_v = vadj.get_upper() - vadj.get_page_size();
                    if (max_v > 0) {
                        double next_v = (cur + velocity).clamp(vadj.get_lower(), max_v);
                        if (next_v != cur) {
                            vadj.set_value(next_v);
                        }
                    }
                }
            }
            return true;
        });

        menu_window.show_all();

        int tx, ty, mw, mh;
        menu_window.get_size(out mw, out mh);
        get_best_pos(mw, mh, out tx, out ty);
        menu_window.move(tx, ty);
    }

    private Widget create_branch_item(string title, bool is_add) {
        var event_box = new EventBox();
        event_box.get_style_context().add_class(is_add ? "add-row" : "note-row");
        event_box.realize.connect(() => {
            event_box.get_window().set_cursor(new Cursor.for_display(Gdk.Display.get_default(), CursorType.HAND2));
        });

        var main_stack = new Stack();
        main_stack.set_transition_type(StackTransitionType.CROSSFADE);

        var normal_box = new Box(Orientation.HORIZONTAL, 10);
        normal_box.set_size_request(220, 38);
        normal_box.set_margin_start(10);
        normal_box.set_margin_end(10);

        var label = new Label(title);
        label.set_xalign(0);
        label.get_style_context().add_class(is_add ? "add-label" : "note-label");
        normal_box.pack_start(label, true, true, 0);

        if (!is_add) {
            var del_trigger = new Label("✕");
            del_trigger.get_style_context().add_class("dim-label");
            normal_box.pack_end(del_trigger, false, false, 0);

            var confirm_box = new Box(Orientation.HORIZONTAL, 8);
            confirm_box.set_size_request(220, 38);
            var sure_lbl = new Label("Sure?");
            sure_lbl.get_style_context().add_class("confirm-label");

            var yes_btn = new Button.with_label("Yes");
            yes_btn.get_style_context().add_class("confirm-btn-yes");
            var no_btn = new Button.with_label("No");
            no_btn.get_style_context().add_class("confirm-btn-no");

            confirm_box.pack_start(sure_lbl, true, true, 0);
            confirm_box.pack_end(no_btn, false, false, 0);
            confirm_box.pack_end(yes_btn, false, false, 0);

            main_stack.add_named(normal_box, "normal");
            main_stack.add_named(confirm_box, "confirm");

            event_box.button_press_event.connect((event) => {
                if (main_stack.get_visible_child_name() == "normal") {
                    if (event.x > 190) main_stack.set_visible_child_name("confirm");
                    else open_editor(title);
                }
                return true;
            });

            yes_btn.clicked.connect(() => { delete_note(title); });
            no_btn.clicked.connect(() => { main_stack.set_visible_child_name("normal"); });
        } else {
            main_stack.add(normal_box);
            event_box.button_press_event.connect((event) => {
                open_editor(null);
                return true;
            });
        }

        event_box.add(main_stack);
        return event_box;
    }

    private void delete_note(string title) {
        string safe_name = title.replace("/", "_");
        var file = File.new_for_path(Path.build_filename(notes_dir, safe_name + ".txt"));
        try { file.delete(); } catch (Error e) {}
        show_menu();
    }

    // ------------------------------------------------------------------------
    // Note Editor Window
    // ------------------------------------------------------------------------

    private void open_editor(string? title) {
        close_menu();
        force_close_editor();

        editing_note_title = title;
        editor_window = new Gtk.Window();
        editor_window.get_style_context().add_class("editor-window");
        editor_window.set_decorated(false);
        editor_window.set_keep_above(true);
        editor_window.set_skip_taskbar_hint(true);
        editor_window.set_skip_pager_hint(true);

        editor_window.set_default_size(300, 420);
        editor_window.set_resizable(true);
        editor_window.set_size_request(200, 200);

        var outer = new Box(Orientation.VERTICAL, 0);
        var container = new Box(Orientation.VERTICAL, 0);
        container.set_margin_top(12);
        container.set_margin_bottom(12);
        container.set_margin_start(14);
        container.set_margin_end(14);

        title_entry = new Entry();
        title_entry.set_has_frame(false);
        title_entry.set_text(title != null ? title : "untitled");

        // Prevent title from automatically selecting text when focused
        title_entry.focus_in_event.connect((event) => {
            Idle.add(() => {
                if (title_entry != null) {
                    title_entry.select_region(0, 0);
                    title_entry.set_position(-1);
                }
                return false;
            });
            return false;
        });

        var header_box = new Box(Orientation.VERTICAL, 0);
        header_box.get_style_context().add_class("editor-header");
        header_box.pack_start(title_entry, false, false, 0);
        container.pack_start(header_box, false, false, 0);

        var scroll = new ScrolledWindow(null, null);
        scroll.set_policy(PolicyType.NEVER, PolicyType.EXTERNAL);
        scroll.set_shadow_type(ShadowType.NONE);

        text_view = new TextView();
        text_view.set_wrap_mode(WrapMode.WORD);
        scroll.add(text_view);
        container.pack_start(scroll, true, true, 0);

        if (title != null) {
            try {
                string content;
                string safe_name = title.replace("/", "_");
                FileUtils.get_contents(Path.build_filename(notes_dir, safe_name + ".txt"), out content);
                text_view.get_buffer().set_text(content);
            } catch (Error e) {}
        }

        text_view.get_buffer().changed.connect(() => { autosave(); });
        title_entry.changed.connect(() => { autosave(); });

        // Auto-save and close when user clicks away
        editor_window.focus_out_event.connect((event) => {
            force_close_editor();
            return false;
        });

        outer.pack_start(container, true, true, 0);

        var resizer = new EventBox();
        resizer.set_size_request(12, 12);
        resizer.set_halign(Align.END);
        resizer.realize.connect(() => {
            resizer.get_window().set_cursor(new Cursor.for_display(Gdk.Display.get_default(), CursorType.BOTTOM_RIGHT_CORNER));
        });
        outer.pack_end(resizer, false, false, 0);

        // Automatic cursor scrolling for editor window
        var editor_vadj = scroll.get_vadjustment();
        editor_window.add_tick_callback((w, clock) => {
            if (editor_window == null) return false;

            var pointer = Gdk.Display.get_default().get_default_seat().get_pointer();
            int rx, ry;
            pointer.get_position(null, out rx, out ry);

            int wx, wy, ww, wh;
            editor_window.get_position(out wx, out wy);
            editor_window.get_size(out ww, out wh);

            if (rx >= wx && rx <= wx + ww && ry >= wy && ry <= wy + wh) {
                double win_y = ry - wy;
                double zone = 60.0;
                double velocity = 0.0;

                // Auto-scroll when near top (below title header) or bottom edge
                if (win_y > 45 && win_y < 45 + zone) {
                    double factor = (zone - (win_y - 45)) / zone;
                    velocity = -2.0 - factor * 8.0;
                } else if (win_y > wh - zone) {
                    double factor = (win_y - (wh - zone)) / zone;
                    velocity = 2.0 + factor * 8.0;
                }

                if (velocity != 0.0) {
                    double cur = editor_vadj.get_value();
                    double max_v = editor_vadj.get_upper() - editor_vadj.get_page_size();
                    if (max_v > 0) {
                        double next_v = (cur + velocity).clamp(editor_vadj.get_lower(), max_v);
                        if (next_v != cur) {
                            editor_vadj.set_value(next_v);
                        }
                    }
                }
            }
            return true;
        });

        editor_window.add(outer);

        int tx, ty, mw, mh;
        editor_window.get_size(out mw, out mh);
        get_best_pos(mw, mh, out tx, out ty);
        editor_window.move(tx, ty);
        editor_window.set_focus(text_view);
        editor_window.show_all();

        // Clear any text selection in the title
        title_entry.select_region(0, 0);
        title_entry.set_position(-1);

        Idle.add(() => {
            if (editor_window == null) return false;
            text_view.grab_focus();
            if (title_entry != null) {
                title_entry.select_region(0, 0);
                title_entry.set_position(-1);
            }
            return false;
        });

        container.bind_property("visible", text_view, "visible", BindingFlags.DEFAULT);
        text_view.button_press_event.connect((e) => { text_view.grab_focus(); return false; });
        title_entry.button_press_event.connect((e) => { 
            title_entry.grab_focus_without_selecting();
            return false; 
        });
    }

    private void autosave() {
        if (title_entry == null || text_view == null) return;

        string new_title = title_entry.get_text().strip();
        if (new_title == "") new_title = "Untitled";

        TextIter start, end;
        text_view.get_buffer().get_bounds(out start, out end);
        string content = text_view.get_buffer().get_text(start, end, false);

        string safe_new_name = new_title.replace("/", "_");

        if (editing_note_title != new_title) {
            if (editing_note_title != null) {
                string safe_old_name = editing_note_title.replace("/", "_");
                var old_file = File.new_for_path(Path.build_filename(notes_dir, safe_old_name + ".txt"));
                try { old_file.delete(); } catch (Error e) {}
            }
            editing_note_title = new_title;
        }

        try {
            FileUtils.set_contents(Path.build_filename(notes_dir, safe_new_name + ".txt"), content);
        } catch (Error e) {}
    }

    private void force_close_editor() {
        if (editor_window != null) {
            autosave();
            editor_window.destroy();
            editor_window = null;
            editing_note_title = null;
        }
    }

    // ------------------------------------------------------------------------
    // System Tray Integration
    // ------------------------------------------------------------------------

    private void setup_tray_icon() {
        string home = Environment.get_home_dir();
        string[] icon_paths = {
            Path.build_filename(home, ".local", "share", "icons", "navwriter.png"),
            "navwriter.png"
        };

        bool icon_loaded = false;
        foreach (string path in icon_paths) {
            if (FileUtils.test(path, FileTest.EXISTS)) {
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale(path, 24, 24, true);
                    tray_icon = new StatusIcon.from_pixbuf(pixbuf);
                    icon_loaded = true;
                    break;
                } catch (Error e) {}
            }
        }

        if (!icon_loaded) {
            tray_icon = new StatusIcon.from_icon_name("accessories-text-editor");
        }

        tray_icon.set_tooltip_text("Navwrite");

        tray_icon.popup_menu.connect((button, time) => {
            var menu = new Gtk.Menu();

            var toggle_item = new Gtk.MenuItem.with_label(hub_window.get_visible() ? "Hide Hub" : "Show Hub");
            toggle_item.activate.connect(() => {
                if (hub_window.get_visible()) {
                    force_close_editor();
                    close_menu();
                    hub_window.hide();
                } else {
                    hub_window.show_all();
                }
            });
            menu.append(toggle_item);

            var settings_item = new Gtk.MenuItem.with_label("Settings...");
            settings_item.activate.connect(() => {
                var dialog = new MessageDialog(
                    null, 
                    DialogFlags.MODAL, 
                    MessageType.INFO, 
                    ButtonsType.OK, 
                    "Settings panel coming soon for the published version!"
                );
                dialog.title = "Navwrite Settings";
                dialog.run();
                dialog.destroy();
            });
            menu.append(settings_item);

            menu.append(new Gtk.SeparatorMenuItem());

            var quit_item = new Gtk.MenuItem.with_label("Quit Navwrite");
            quit_item.activate.connect(() => {
                force_close_editor();
                app.quit();
            });
            menu.append(quit_item);

            menu.show_all();
            menu.popup(null, null, tray_icon.position_menu, button, time);
        });
    }

    // ------------------------------------------------------------------------
    // Program Entry Point
    // ------------------------------------------------------------------------

    public static int main(string[] args) {
        var app = new StickyApp();
        return app.run(args);
    }
}
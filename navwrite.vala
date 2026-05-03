/*
 * Compilation:
 * valac --pkg gtk+-3.0 sticky_hub.vala -X -lm
 * * NOTE: The "-X -lm" part is CRITICAL because we use math functions (sin) 
 * for the diode pulse animation.
 */

using Gtk;
using Gdk;

public class StickyApp : GLib.Object {
    private Gtk.Application app;
    private Gtk.Window hub_window;
    private Gtk.Window menu_window;
    private Gtk.Window editor_window;
    
    private StatusIcon tray_icon;
    
    private string notes_dir;
    private string? editing_note_title = null;
    
    private int hub_x = 100;
    private int hub_y = 100;
    private int circle_size = 56;
    private int gap = 15; 

    private double pulse_alpha = 1.0;
    private double pulse_scale = 1.0;

    private RGBA accent_green_rgba;
    
    private bool is_context_menu_open = false;
    private int64 last_editor_close_time = 0;

    public StickyApp() {
        string dropbox_path = Path.build_filename(Environment.get_home_dir(), "Dropbox");
        if (FileUtils.test(dropbox_path, FileTest.EXISTS | FileTest.IS_DIR)) {
            notes_dir = Path.build_filename(dropbox_path, "StickyNotes");
        } else {
            notes_dir = Path.build_filename(Environment.get_home_dir(), "StickyNotes");
        }
        DirUtils.create_with_parents(notes_dir, 0755);

        
        app = new Gtk.Application("com.navwrite.stickybubble", ApplicationFlags.DEFAULT_FLAGS);
        app.activate.connect(on_activate);
    }

    private void init_styles() {
        var provider = new CssProvider();
        string css = """
            .sticky-card { 
                background-color: #1e1e1e; 
                border-radius: 12px; 
                border: 1px solid #333333;
                box-shadow: 0 4px 12px rgba(0,0,0,0.5);
            }
            .note-label { color: #eeeeee; font-weight: bold; font-size: 10pt; }
            .add-label { color: #2ecc71; font-weight: bold; font-size: 10pt; }
            .confirm-label { color: #ff453a; font-weight: bold; font-size: 9pt; }
            .dim-label { color: #555555; }
            .editor-window { background-color: #1e1e1e; border-radius: 12px; border: 1px solid #333333; }
            entry { 
                background: none; 
                border: none; 
                color: #aaaaaa; 
                font-weight: bold; 
                font-size: 11pt; 
                box-shadow: none; 
            }
            textview text { 
                background-color: #1e1e1e; 
                color: #ffffff; 
                font-size: 11pt; 
            }
            entry:focus, textview:focus { border: none; box-shadow: none; outline: none; }
        """;
        try {
            provider.load_from_data(css, -1);
            StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            stderr.printf("CSS Error: %s\n", e.message);
        }
    }

    private void on_activate() {
        app.hold();
        
        init_styles();
        create_hub();
        setup_tray_icon();
    }

    private void setup_tray_icon() {
        string home = Environment.get_home_dir();
        string[] icon_paths = {
        };

        bool icon_loaded = false;
        foreach (string path in icon_paths) {
            if (FileUtils.test(path, FileTest.EXISTS)) {
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale(path, 24, 24, true);
                    tray_icon = new StatusIcon.from_pixbuf(pixbuf);
                    icon_loaded = true;
                    break;
                } catch (Error e) {
                }
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
                    if (menu_window != null) {
                        menu_window.destroy();
                        menu_window = null;
                    }
                    hub_window.hide();
                } else {
                    hub_window.show_all();
                }
            });
            menu.append(toggle_item);

            var settings_item = new Gtk.MenuItem.with_label("Settings...");
            settings_item.activate.connect(() => {
                var dialog = new MessageDialog(null, DialogFlags.MODAL, MessageType.INFO, ButtonsType.OK, "Settings panel coming soon for the published version!");
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
            ctx.set_source_rgba(accent_green_rgba.red, accent_green_rgba.green, accent_green_rgba.blue, pulse_alpha);
            double r = (circle_size / 2 - 6) * pulse_scale;
            ctx.arc(circle_size / 2, circle_size / 2, r, 0, 2 * Math.PI);
            ctx.fill();
            
            ctx.set_source_rgba(accent_green_rgba.red * 0.5, accent_green_rgba.green * 0.5, accent_green_rgba.blue * 0.5, 0.8);
            ctx.arc(circle_size / 2, circle_size / 2, 8, 0, 2 * Math.PI);
            ctx.fill();
            return true;
        });

        hub_window.add_tick_callback ((w, clock) => {
            double time = clock.get_frame_time () / 1000000.0;
            pulse_alpha = 0.7 + 0.3 * Math.sin (time * 0.5);
            pulse_scale = 1.0 + 0.05 * Math.sin (time * 0.5);
            drawing_area.queue_draw ();
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
                int64 now = GLib.get_monotonic_time();
                if (editor_window != null) {
                    force_close_editor();
                } else if (now - last_editor_close_time > 200000) {
                    toggle_menu();
                }
            }
            return true;
        });

        hub_window.move(hub_x, hub_y);
        hub_window.show_all();
        app.add_window(hub_window);
    }

    private void refresh_child_positions() {
        int tx, ty, mw, mh;
        if (menu_window != null) {
            menu_window.get_size(out mw, out mh);
            get_best_pos(mw, mh, out tx, out ty);
            int cur_x, cur_y;
            menu_window.get_position(out cur_x, out cur_y);
            if (cur_x != tx || cur_y != ty) {
                menu_window.move(tx, ty);
            }
        }
        if (editor_window != null) {
            editor_window.get_size(out mw, out mh);
            get_best_pos(mw, mh, out tx, out ty);
            int cur_x, cur_y;
            editor_window.get_position(out cur_x, out cur_y);
            if (cur_x != tx || cur_y != ty) {
                editor_window.move(tx, ty);
            }
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

    private void toggle_menu() {
        if (menu_window != null) {
            menu_window.destroy();
            menu_window = null;
            return;
        }

        menu_window = new Gtk.Window();
        menu_window.get_style_context().add_class("sticky-card");
        menu_window.set_type_hint(WindowTypeHint.UTILITY);
        menu_window.set_decorated(false);
        menu_window.set_keep_above(true);
        menu_window.set_skip_taskbar_hint(true);

        var box = new Box(Orientation.VERTICAL, 4);
        box.set_border_width(8);

        int count = 0;
        try {
            var directory = File.new_for_path(notes_dir);
            var enumerator = directory.enumerate_children("standard::name", FileQueryInfoFlags.NONE);
            FileInfo info;
            while ((info = enumerator.next_file()) != null && count < 10) {
                if (info.get_name().has_suffix(".txt")) {
                    box.add(create_branch_item(info.get_name().replace(".txt", ""), false));
                    count++;
                }
            }
        } catch (Error e) {}

        box.add(create_branch_item("+ New Note", true));
        menu_window.add(box);
        menu_window.show_all();
        
        int tx, ty, mw, mh;
        menu_window.get_size(out mw, out mh);
        get_best_pos(mw, mh, out tx, out ty);
        menu_window.move(tx, ty);
    }

    private Widget create_branch_item(string title, bool is_add) {
        var event_box = new EventBox();
        var main_stack = new Stack();
        main_stack.set_transition_type(StackTransitionType.CROSSFADE);
        
        var normal_box = new Box(Orientation.HORIZONTAL, 10);
        normal_box.set_size_request(220, 42);
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
            confirm_box.set_size_request(220, 42);
            var sure_lbl = new Label("Sure?");
            sure_lbl.get_style_context().add_class("confirm-label");
            
            var yes_btn = new Button.with_label("Yes");
            var no_btn = new Button.with_label("No");
            
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
        var file = File.new_for_path(Path.build_filename(notes_dir, title + ".txt"));
        try { file.delete(); } catch (Error e) {}
        toggle_menu();
        toggle_menu();
    }

    private Entry title_entry;
    private TextView text_view;

    private void open_editor(string? title) {
        if (menu_window != null) menu_window.destroy();
        menu_window = null;

        editing_note_title = title;
        editor_window = new Gtk.Window();
        editor_window.get_style_context().add_class("editor-window");
        editor_window.set_decorated(false);
        editor_window.set_keep_above(true);
        editor_window.set_skip_taskbar_hint(true);
        editor_window.set_skip_pager_hint(true);
        
        editor_window.set_resizable(true);
        editor_window.set_default_size(300, 420);
        editor_window.set_size_request(200, 200);

        editor_window.size_allocate.connect((alloc) => {
            refresh_child_positions();
        });

        var outer = new Box(Orientation.VERTICAL, 0);
        var container = new Box(Orientation.VERTICAL, 0);
        container.set_margin_top(10);
        container.set_margin_bottom(10);
        container.set_margin_start(10);
        container.set_margin_end(10);

        title_entry = new Entry();
        title_entry.set_has_frame(false);
        title_entry.set_width_chars(1);
        title_entry.set_max_width_chars(1);
        title_entry.set_text(title != null ? title : "untitled");
        container.pack_start(title_entry, false, false, 0);

        var scroll = new ScrolledWindow(null, null);
        scroll.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        scroll.propagate_natural_width = false;
        scroll.propagate_natural_height = false;
        text_view = new TextView();
        text_view.set_wrap_mode(WrapMode.WORD);
        scroll.add(text_view);
        container.pack_start(scroll, true, true, 0);

        if (title != null) {
            try {
                string content;
                FileUtils.get_contents(Path.build_filename(notes_dir, title + ".txt"), out content);
                text_view.get_buffer().set_text(content);
            } catch (Error e) {}
        }

        text_view.get_buffer().changed.connect(() => { autosave(); });
        title_entry.changed.connect(() => { autosave(); });

        title_entry.populate_popup.connect((popup) => {
            var menu = popup as Gtk.Menu;
            if (menu != null) {
                is_context_menu_open = true;
                menu.deactivate.connect(() => {
                    is_context_menu_open = false;
                    GLib.Idle.add(() => {
                        if (editor_window != null && !editor_window.is_active) {
                            force_close_editor();
                        }
                        return false;
                    });
                });
            }
        });

        text_view.populate_popup.connect((popup) => {
            var menu = popup as Gtk.Menu;
            if (menu != null) {
                is_context_menu_open = true;
                menu.deactivate.connect(() => {
                    is_context_menu_open = false;
                    GLib.Idle.add(() => {
                        if (editor_window != null && !editor_window.is_active) {
                            force_close_editor();
                        }
                        return false;
                    });
                });
            }
        });

        editor_window.focus_out_event.connect((event) => {
            if (!is_context_menu_open) {
                force_close_editor();
            }
            return false;
        });

        outer.pack_start(container, true, true, 0);

        var resizer = new EventBox();
        resizer.set_size_request(10, 10);
        resizer.set_halign(Align.END);
        resizer.realize.connect (() => {
            resizer.get_window ().set_cursor (new Cursor.for_display(Gdk.Display.get_default(), CursorType.BOTTOM_RIGHT_CORNER));
        });
        resizer.button_press_event.connect((event) => {
            if (event.button == 1) {
                editor_window.begin_resize_drag(WindowEdge.SOUTH_EAST, 1, (int)event.x_root, (int)event.y_root, event.time);
            }
            return true;
        });
        outer.pack_end(resizer, false, false, 0);
        
        editor_window.add(outer);
        
        int tx, ty, mw, mh;
        editor_window.get_size(out mw, out mh);
        get_best_pos(mw, mh, out tx, out ty);
        editor_window.move(tx, ty);
        editor_window.show_all();
        
        Idle.add(() => {
            if (editor_window == null) return false;
            if (editing_note_title == null) title_entry.grab_focus();
            else text_view.grab_focus();
            return false;
        });

        container.bind_property("visible", text_view, "visible", BindingFlags.DEFAULT);
        text_view.button_press_event.connect((e) => { text_view.grab_focus(); return false; });
        title_entry.button_press_event.connect((e) => { title_entry.grab_focus(); return false; });
    }

    private void autosave() {
        if (title_entry == null || text_view == null) return;
        
        string new_title = title_entry.get_text().strip();
        if (new_title == "") new_title = "Untitled";
        
        TextIter start, end;
        text_view.get_buffer().get_bounds(out start, out end);
        string content = text_view.get_buffer().get_text(start, end, false);

        if (editing_note_title != new_title) {
            if (editing_note_title != null) {
                var old_file = File.new_for_path(Path.build_filename(notes_dir, editing_note_title + ".txt"));
                try { old_file.delete(); } catch (Error e) {}
            }
            editing_note_title = new_title; 
        }

        try {
            FileUtils.set_contents(Path.build_filename(notes_dir, new_title + ".txt"), content);
        } catch (Error e) {}
    }

    private void force_close_editor() {
        if (editor_window != null) {
            autosave();
            editor_window.destroy();
            editor_window = null;
            editing_note_title = null;
            last_editor_close_time = GLib.get_monotonic_time();
        }
    }

    public int run(string[] args) {
        return app.run(args);
    }

    public static int main(string[] args) {
        var app = new StickyApp();
        return app.run(args);
    }
}
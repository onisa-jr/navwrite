using GLib;

public class AppSettings : Object {
    private static AppSettings _instance;
    private KeyFile keyfile;
    private string config_path;

    public string accent_color { get; set; default = "#2ecc71"; }
    public string bg_color { get; set; default = "#1e1e1e"; }
    public double opacity { get; set; default = 0.95; }
    public int font_size { get; set; default = 11; }

    private AppSettings() {
        config_path = Path.build_filename(Environment.get_user_config_dir(), "navwrite", "settings.ini");
        DirUtils.create_with_parents(Path.get_dirname(config_path), 0755);
        
        keyfile = new KeyFile();
        load();
    }

    public static AppSettings get_instance() {
        if (_instance == null) {
            _instance = new AppSettings();
        }
        return _instance;
    }

    public void load() {
        try {
            keyfile.load_from_file(config_path, KeyFileFlags.NONE);
            accent_color = keyfile.get_string("Theme", "AccentColor");
            bg_color = keyfile.get_string("Theme", "BackgroundColor");
            opacity = keyfile.get_double("Theme", "Opacity");
            font_size = keyfile.get_integer("Theme", "FontSize");
        } catch (Error e) {
            // Use defaults if file doesn't exist or is invalid
        }
    }

    public void save() {
        keyfile.set_string("Theme", "AccentColor", accent_color);
        keyfile.set_string("Theme", "BackgroundColor", bg_color);
        keyfile.set_double("Theme", "Opacity", opacity);
        keyfile.set_integer("Theme", "FontSize", font_size);

        try {
            string data = keyfile.to_data(null);
            FileUtils.set_contents(config_path, data);
        } catch (Error e) {
            stderr.printf("Error saving settings: %s\n", e.message);
        }
    }
}

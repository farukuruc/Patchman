// Included beside the already tested profile reader; no new DSP or coefficient math.
use std::path::PathBuf;

fn json_string(value: &str) -> String {
    let mut out = String::from("\"");
    for ch in value.chars() {
        match ch {
            '"' => out.push_str("\\\""), '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"), '\r' => out.push_str("\\r"), '\t' => out.push_str("\\t"),
            ch if ch < ' ' => out.push_str(&format!("\\u{:04x}", ch as u32)),
            ch => out.push(ch),
        }
    }
    out.push('"');
    out
}

fn atomic_text(output: &Path, text: &str) -> Result<(), String> {
    atomic_text_mode(output, text, false)
}

fn selection_permission_result(result: io::Result<()>, portable: bool) -> Result<(), String> {
    match result {
        Ok(()) => Ok(()),
        // USB-visible FAT storage can accept writes but reject Unix chmod.
        // Only active.txt gets this exception, never the runtime/control files.
        Err(error) if portable && matches!(error.raw_os_error(), Some(1 | 38 | 95)) => Ok(()),
        Err(error) => Err(format!("set permissions: {error}")),
    }
}

fn save_selection(output: &Path, text: &str) -> Result<(), String> {
    atomic_text_mode(output, text, true)
}

fn atomic_text_mode(output: &Path, text: &str, portable: bool) -> Result<(), String> {
    #[cfg(not(unix))] let _ = portable;
    let parent = output.parent().ok_or("missing parent")?;
    let temporary = parent.join(format!(".ui-{}-{}", output.file_name().ok_or("missing filename")?.to_string_lossy(), std::process::id()));
    let result = (|| {
        let mut file = OpenOptions::new().write(true).create_new(true).open(&temporary).map_err(|e| format!("create temporary file: {e}"))?;
        file.write_all(text.as_bytes()).map_err(|e| format!("write temporary file: {e}"))?;
        file.sync_all().map_err(|e| format!("sync temporary file: {e}"))?;
        #[cfg(unix)] {
            use std::os::unix::fs::PermissionsExt;
            selection_permission_result(fs::set_permissions(&temporary, fs::Permissions::from_mode(0o644)), portable)?;
        }
        fs::rename(&temporary, output).map_err(|e| format!("activate file: {e}"))
    })();
    if result.is_err() { let _ = fs::remove_file(&temporary); }
    result
}

fn bounded_text(path: &Path, limit: u64) -> Result<String, String> {
    let mut text = String::new();
    File::open(path).map_err(|e| e.to_string())?.take(limit + 1).read_to_string(&mut text).map_err(|e| e.to_string())?;
    if text.len() as u64 > limit { return Err("file too large".into()); }
    Ok(text.trim_start_matches('\u{feff}').trim().to_string())
}

fn valid_profile_name(name: &str) -> bool {
    !name.is_empty() && name.len() <= 255 && !name.contains(['/', '\\', '\r', '\n', '\0'])
        && !name.eq_ignore_ascii_case("active.txt") && name.to_ascii_lowercase().ends_with(".txt")
}

struct UiState { directory: PathBuf, runtime: PathBuf }
impl UiState {
    fn control(&self) -> PathBuf { self.runtime.join("cinder_hpeq") }
    fn backend_ready(&self) -> bool {
        !self.runtime.parent().unwrap().join("off").exists()
            && !self.directory.parent().unwrap().join("peq_off").exists()
            && self.runtime.join("cinder_mono_shim").is_file()
    }
    fn names(&self) -> Result<Vec<String>, String> {
        let mut names = Vec::new();
        for entry in fs::read_dir(&self.directory).map_err(|e| e.to_string())? {
            let entry = entry.map_err(|e| e.to_string())?;
            if !entry.file_type().map_err(|e| e.to_string())?.is_file() { continue; }
            if let Some(name) = entry.file_name().to_str() {
                if valid_profile_name(name) {
                    names.push(name.to_string());
                    if names.len() > 128 { return Err("More than 128 profiles; reduce the PEQ folder".into()); }
                }
            }
        }
        names.sort_by_key(|name| name.to_lowercase());
        Ok(names)
    }
    fn selection(&self) -> String {
        bounded_text(&self.directory.join("active.txt"), 1024).unwrap_or_else(|_| "off".into())
    }
    fn selected(&self) -> String {
        let active = self.selection();
        if valid_profile_name(&active) { active }
        else { bounded_text(&self.runtime.join("ui-last-profile"), 1024).ok().filter(|s| valid_profile_name(s)).unwrap_or_default() }
    }
    fn publish(&self, id: &str, error: Option<&str>) -> Result<(), String> {
        let names = self.names();
        let error = error.map(str::to_string).or_else(|| names.as_ref().err().cloned());
        let enabled = self.backend_ready() && valid_profile_name(&self.selection())
            && fs::metadata(self.control()).map(|m| m.len() > 0).unwrap_or(false);
        let profiles = names.unwrap_or_default().iter().map(|name| json_string(name)).collect::<Vec<_>>().join(",");
        let body = format!("{{\"requestId\":{},\"ok\":{},\"error\":{},\"enabled\":{},\"backendReady\":{},\"selected\":{},\"profiles\":[{}]}}\n",
            json_string(id), error.is_none(), json_string(error.as_deref().unwrap_or("")), enabled,
            self.backend_ready(), json_string(&self.selected()), profiles);
        atomic_text(&self.runtime.join("ui-state.json"), &body)
    }
    fn change(&self, selection: &str) -> Result<(), String> {
        if !self.backend_ready() { return Err("PEQ backend unavailable; restart and check the PEQ log".into()); }
        let profile = if selection == "off" { None } else {
            if !valid_profile_name(selection) { return Err("Invalid profile filename".into()); }
            let path = self.directory.join(selection);
            if !fs::symlink_metadata(&path).map_err(|e| e.to_string())?.is_file() { return Err("Profile is not a regular file".into()); }
            Some(read_profile(&path)?)
        };
        let active = self.directory.join("active.txt");
        let previous = bounded_text(&active, 1024).unwrap_or_else(|_| "off".into());
        save_selection(&active, &format!("{selection}\n")).map_err(|e| format!("Cannot save selection: {e}"))?;
        let applied = match &profile { Some(p) => write_control(p, &self.control()), None => disable(&self.control()) };
        if let Err(error) = applied {
            let restore = save_selection(&active, &format!("{previous}\n"));
            return Err(format!("Cannot apply profile: {error}; selection restored: {}", restore.is_ok()));
        }
        if profile.is_some() {
            // Optional convenience state, separate from the actual persisted active selection.
            let _ = atomic_text(&self.runtime.join("ui-last-profile"), selection);
        }
        Ok(())
    }
    fn request(&self, text: &str) -> (String, Result<(), String>) {
        let lines = text.lines().collect::<Vec<_>>();
        let id = lines.first().copied().unwrap_or("");
        if id.is_empty() || id.len() > 64 || !id.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-') {
            return (String::new(), Err("Invalid request ID".into()));
        }
        let result = match lines.as_slice() {
            [_, "refresh"] => Ok(()),
            [_, "off"] => self.change("off"),
            [_, "load", name] => self.change(name),
            _ => Err("Invalid PEQ request".into()),
        };
        (id.to_string(), result)
    }
}

#[cfg(target_os = "linux")]
fn serve(state: &UiState) -> Result<(), String> {
    use std::os::fd::{AsRawFd, FromRawFd};
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;
    unsafe extern "C" {
        fn inotify_init1(flags: i32) -> i32;
        fn inotify_add_watch(fd: i32, path: *const std::os::raw::c_char, mask: u32) -> i32;
        fn flock(fd: i32, operation: i32) -> i32;
        fn signal(sig: i32, handler: usize) -> usize;
    }
    fs::create_dir_all(&state.runtime).map_err(|e| e.to_string())?;
    let lock = OpenOptions::new().create(true).truncate(false).write(true).open(state.runtime.join("ui-server.lock")).map_err(|e| e.to_string())?;
    if unsafe { flock(lock.as_raw_fd(), 2 | 4) } != 0 { return Ok(()); }
    unsafe { signal(1, 1); } // Parent UI restarts must not terminate the sleeping helper.
    let fd = unsafe { inotify_init1(0x80000) }; // IN_CLOEXEC
    if fd < 0 { return Err(io::Error::last_os_error().to_string()); }
    let mut events = unsafe { File::from_raw_fd(fd) };
    let directory = CString::new(state.runtime.as_os_str().as_bytes()).map_err(|e| e.to_string())?;
    if unsafe { inotify_add_watch(fd, directory.as_ptr(), 0x8 | 0x80) } < 0 { return Err(io::Error::last_os_error().to_string()); }
    state.publish("", None)?;
    println!("PEQ UI helper ready; waiting for file events");
    let mut buffer = [0u8; 8192];
    loop {
        let size = match events.read(&mut buffer) {
            Ok(0) => return Err("inotify closed".into()),
            Ok(n) => n,
            Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
            Err(e) => return Err(e.to_string()),
        };
        let mut offset = 0;
        let mut requested = false;
        while offset + 16 <= size {
            let len = u32::from_ne_bytes(buffer[offset + 12..offset + 16].try_into().unwrap()) as usize;
            if offset + 16 + len > size { break; }
            let name = &buffer[offset + 16..offset + 16 + len];
            if name.split(|b| *b == 0).next() == Some(b"ui-command".as_slice()) { requested = true; }
            offset += 16 + len;
        }
        if requested {
            let (id, result) = match bounded_text(&state.runtime.join("ui-command"), 1024) {
                Ok(text) => state.request(&text), Err(e) => (String::new(), Err(e)),
            };
            state.publish(&id, result.as_ref().err().map(String::as_str))?;
        }
    }
}

pub fn ui_main() {
    let args = env::args().skip(1).collect::<Vec<_>>();
    let result: Result<(), String> = match args.as_slice() {
        [command, directory, runtime] if command == "serve" => {
            let state = UiState { directory: directory.into(), runtime: runtime.into() };
            #[cfg(target_os = "linux")] { serve(&state) }
            #[cfg(not(target_os = "linux"))] { let _ = state; Err("serve requires Linux".into()) }
        }
        _ => Err("usage: sony-peq-ui serve PROFILE_DIRECTORY RUNTIME_DIRECTORY".into()),
    };
    if let Err(error) = result { eprintln!("PEQ UI ERROR: {error}"); std::process::exit(1); }
}

#[cfg(test)]
mod ui_tests {
    use super::*;
    #[test] fn usb_selection_tolerates_unsupported_chmod_but_not_other_write_errors() {
        for code in [1, 38, 95] {
            assert!(selection_permission_result(Err(io::Error::from_raw_os_error(code)), true).is_ok());
            assert!(selection_permission_result(Err(io::Error::from_raw_os_error(code)), false).is_err());
        }
        for code in [13, 28, 30] {
            assert!(selection_permission_result(Err(io::Error::from_raw_os_error(code)), true).is_err());
        }
    }
    fn fixture() -> UiState {
        use std::sync::atomic::{AtomicUsize, Ordering};
        static NEXT: AtomicUsize = AtomicUsize::new(0);
        let root = env::temp_dir().join(format!("peq-ui-{}-{}", std::process::id(), NEXT.fetch_add(1, Ordering::Relaxed)));
        let state = UiState { directory: root.join("contents/PEQ"), runtime: root.join("data/sony-peq/runtime") };
        fs::create_dir_all(&state.directory).unwrap(); fs::create_dir_all(&state.runtime).unwrap();
        fs::write(state.runtime.join("cinder_mono_shim"), "100").unwrap();
        fs::write(state.directory.join("Gate.txt"), "Preamp: -2 dB\nFilter 1: ON PK Fc 33 Hz Gain -4 dB Q 0.35\n").unwrap();
        fs::write(state.directory.join("Shelf.txt"), "Filter 1: ON LSC Fc 100 Hz Gain 2 dB Q 0.7\nFilter 2: ON HSC Fc 8000 Hz Gain -2 dB Q 0.7\n").unwrap();
        state
    }
    fn cleanup(state: UiState) { fs::remove_dir_all(state.directory.parent().unwrap().parent().unwrap()).unwrap(); }
    #[test] fn live_selection_off_and_shelf_use_same_control_format() {
        let s = fixture(); s.change("Gate.txt").unwrap();
        let gate = fs::read_to_string(s.control()).unwrap();
        s.change("Shelf.txt").unwrap(); assert_ne!(gate, fs::read_to_string(s.control()).unwrap());
        assert_eq!(s.selection(), "Shelf.txt");
        s.change("off").unwrap(); assert!(!s.control().exists()); assert_eq!(s.selected(), "Shelf.txt");
        cleanup(s);
    }
    #[test] fn bad_profiles_and_requests_preserve_current_sound() {
        let s = fixture(); s.change("Gate.txt").unwrap(); let original = fs::read(s.control()).unwrap();
        fs::write(s.directory.join("Bad.txt"), "Filter 1: ON PK Fc 1000 Hz Gain NaN dB Q 1\n").unwrap();
        for text in ["a\nload\n../Gate.txt", "b\nload\nBad.txt", "c\nload\nMissing.txt", "d\nexec\nanything", "e\nload\nGate.txt\nextra"] {
            assert!(s.request(text).1.is_err()); assert_eq!(fs::read(s.control()).unwrap(), original);
            assert_eq!(s.selection(), "Gate.txt");
        }
        cleanup(s);
    }
    #[test] fn disabled_backend_cannot_be_enabled_from_ui() {
        let s = fixture(); fs::write(s.runtime.parent().unwrap().join("off"), "").unwrap();
        assert!(s.change("Gate.txt").is_err()); assert!(!s.control().exists()); cleanup(s);
    }
    #[test] fn catalog_escapes_names_and_excludes_active_and_directories() {
        let s = fixture(); fs::write(s.directory.join("active.txt"), "off").unwrap();
        fs::write(s.directory.join("Quote\".txt"), "unused").unwrap();
        fs::create_dir(s.directory.join("Folder.txt")).unwrap();
        s.publish("req-1", None).unwrap(); let text = fs::read_to_string(s.runtime.join("ui-state.json")).unwrap();
        assert!(text.contains("Quote\\\".txt")); assert!(!text.contains("active.txt")); assert!(!text.contains("Folder.txt"));
        cleanup(s);
    }
    #[test] fn selection_write_failure_does_not_change_current_filters() {
        let s = fixture(); s.change("Gate.txt").unwrap(); let original = fs::read(s.control()).unwrap();
        fs::remove_file(s.directory.join("active.txt")).unwrap();
        fs::create_dir(s.directory.join("active.txt")).unwrap();
        assert!(s.change("Shelf.txt").is_err()); assert_eq!(fs::read(s.control()).unwrap(), original);
        cleanup(s);
    }
    #[test] fn control_write_failure_restores_previous_selection() {
        let s = fixture(); s.change("Gate.txt").unwrap();
        fs::remove_file(s.control()).unwrap(); fs::create_dir(s.control()).unwrap();
        assert!(s.change("Shelf.txt").is_err()); assert_eq!(s.selection(), "Gate.txt");
        cleanup(s);
    }
}

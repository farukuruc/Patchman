use std::env;
use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Write};
use std::path::Path;

const MAX_PROFILE_BYTES: u64 = 65536;

fn read_profile(path: &Path) -> Result<hp_eq::Profile, String> {
    let mut text = String::new();
    File::open(path)
        .map_err(|error| format!("{}: {error}", path.display()))?
        .take(MAX_PROFILE_BYTES + 1)
        .read_to_string(&mut text)
        .map_err(|error| format!("cannot read profile: {error}"))?;
    if text.len() as u64 > MAX_PROFILE_BYTES {
        return Err("profile exceeds 64 KiB".into());
    }
    let profile = hp_eq::parse(&text)?;
    if !profile.preamp_db.is_finite()
        || profile.filters.iter().any(|filter| {
            !filter.hz.is_finite() || !filter.db.is_finite() || !filter.q.is_finite()
        })
    {
        return Err("profile contains a non-finite value".into());
    }
    Ok(profile)
}

fn disable(output: &Path) -> Result<(), String> {
    match fs::remove_file(output) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(format!("cannot disable PEQ: {error}")),
    }
}

fn write_control(profile: &hp_eq::Profile, output: &Path) -> Result<(), String> {
    let body = hp_eq::control(profile);
    if body.is_empty() {
        return Err("profile produced no filters".into());
    }
    let parent = output.parent().ok_or("output has no parent directory")?;
    fs::create_dir_all(parent).map_err(|error| format!("output directory: {error}"))?;
    let name = output.file_name().ok_or("output has no file name")?;
    let temporary = parent.join(format!(".{}.{}.new", name.to_string_lossy(), std::process::id()));
    let result = (|| -> Result<(), String> {
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&temporary)
            .map_err(|error| format!("temporary control file: {error}"))?;
        file.write_all(body.as_bytes()).map_err(|error| error.to_string())?;
        file.sync_all().map_err(|error| error.to_string())?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&temporary, fs::Permissions::from_mode(0o644))
                .map_err(|error| error.to_string())?;
        }
        fs::rename(&temporary, output).map_err(|error| format!("activate control file: {error}"))?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(temporary);
    }
    result
}

fn compile_profile(input: &Path, output: &Path) -> Result<(), String> {
    let profile = read_profile(input)?;
    write_control(&profile, output)?;
    println!(
        "PEQ ready: {} filters, profile preamp {} dB, {} sample rates",
        profile.filters.len(), profile.preamp_db, hp_eq::RATES.len()
    );
    Ok(())
}

fn select_profile(directory: &Path, output: &Path) -> Result<(), String> {
    let result = (|| -> Result<(), String> {
        let mut selection = String::new();
        match File::open(directory.join("active.txt")) {
            Ok(file) => {
                file.take(1025).read_to_string(&mut selection)
                    .map_err(|error| format!("cannot read active.txt: {error}"))?;
            }
            Err(error) if error.kind() == io::ErrorKind::NotFound => {
                disable(output)?;
                println!("PEQ off: no active.txt");
                return Ok(());
            }
            Err(error) => return Err(format!("cannot open active.txt: {error}")),
        }
        if selection.len() > 1024 {
            return Err("active.txt exceeds 1 KiB".into());
        }
        let name = selection.trim_start_matches('\u{feff}').trim();
        if name.eq_ignore_ascii_case("off") {
            disable(output)?;
            println!("PEQ off");
            return Ok(());
        }
        if name.is_empty() || name.contains(['/', '\\', '\r', '\n', '\0'])
            || name.eq_ignore_ascii_case("active.txt")
            || !name.to_ascii_lowercase().ends_with(".txt")
        {
            return Err("active.txt must contain one profile filename, or off".into());
        }
        compile_profile(&directory.join(name), output)?;
        println!("Selected profile: {name}");
        Ok(())
    })();
    if result.is_err() {
        disable(output)?;
    }
    result
}

fn run(args: &[String]) -> Result<(), String> {
    match args {
        [command, input] if command == "check" => {
            let profile = read_profile(Path::new(input))?;
            println!("PROFILE OK: {} filters, preamp {} dB", profile.filters.len(), profile.preamp_db);
            for (index, filter) in profile.filters.iter().enumerate() {
                println!("{}: {:?}, {} Hz, {} dB, Q {}", index + 1, filter.kind, filter.hz, filter.db, filter.q);
            }
            Ok(())
        }
        [command, input, output] if command == "compile" => {
            compile_profile(Path::new(input), Path::new(output))
        }
        [command, directory, output] if command == "select" => {
            let output = Path::new(output);
            if Path::new("/contents/peq_off").exists() {
                disable(output)?;
                println!("PEQ off: peq_off present");
                return Ok(());
            }
            select_profile(Path::new(directory), output)
        }
        [command, input, output] if command == "apply" => {
            let output = Path::new(output);
            if Path::new("/contents/peq_off").exists() || !Path::new(input).exists() {
                disable(output)?;
                println!("PEQ off");
                return Ok(());
            }
            if let Err(error) = compile_profile(Path::new(input), output) {
                disable(output)?;
                return Err(error);
            }
            Ok(())
        }
        [command, output] if command == "off" => disable(Path::new(output)),
        _ => Err("usage: sony-peq-profile check INPUT | compile INPUT OUTPUT | select DIRECTORY OUTPUT | apply INPUT OUTPUT | off OUTPUT".into()),
    }
}

fn main() {
    // Bound boot-time profile loading if the removable filesystem stalls.
    #[cfg(unix)]
    unsafe {
        unsafe extern "C" { fn alarm(seconds: u32) -> u32; }
        alarm(5);
    }
    let args = env::args().skip(1).collect::<Vec<_>>();
    if let Err(error) = run(&args) {
        eprintln!("PEQ ERROR: {error}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod profile_tests {
    use super::*;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicUsize, Ordering};
    static NEXT: AtomicUsize = AtomicUsize::new(0);

    fn directory() -> PathBuf {
        let path = env::temp_dir().join(format!(
            "sony-peq-test-{}-{}", std::process::id(), NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir_all(&path).unwrap();
        path
    }

    #[test]
    fn compiles_four_band_profile_and_can_disable_it() {
        let dir = directory();
        let input = dir.join("Gate.txt");
        let output = dir.join("active");
        fs::write(&input, "Preamp: -2 dB\nFilter 1: ON PK Fc 33 Hz Gain -4 dB Q 0.35\nFilter 2: ON PK Fc 410 Hz Gain 1 dB Q 0.4\nFilter 3: ON PK Fc 2000 Hz Gain 1.5 dB Q 1.5\nFilter 4: ON PK Fc 4700 Hz Gain -3.5 dB Q 1.5\n").unwrap();
        compile_profile(&input, &output).unwrap();
        let text = fs::read_to_string(&output).unwrap();
        assert_eq!(text.lines().count(), 9);
        assert!(text.lines().all(|line| line.split_whitespace().count() == 21));
        disable(&output).unwrap();
        assert!(!output.exists());
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn invalid_apply_disables_previous_profile() {
        let dir = directory();
        let input = dir.join("bad.txt");
        let output = dir.join("active");
        fs::write(&input, "Filter 1: ON PK Fc 1000 Hz Gain NaN dB Q 1\n").unwrap();
        fs::write(&output, "old filters").unwrap();
        assert!(run(&["apply".into(), input.display().to_string(), output.display().to_string()]).is_err());
        assert!(!output.exists());
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn switches_headphone_profiles_and_turns_off() {
        let dir = directory();
        let output = dir.join("control");
        fs::write(dir.join("Gate.txt"), "Filter 1: ON PK Fc 33 Hz Gain -4 dB Q 0.35\n").unwrap();
        fs::write(dir.join("Other IEM.txt"), "Filter 1: ON PK Fc 1000 Hz Gain -2 dB Q 1\n").unwrap();
        fs::write(dir.join("active.txt"), "\u{feff}Gate.txt\r\n").unwrap();
        select_profile(&dir, &output).unwrap();
        let gate = fs::read_to_string(&output).unwrap();
        fs::write(dir.join("active.txt"), "Other IEM.txt\n").unwrap();
        select_profile(&dir, &output).unwrap();
        assert_ne!(gate, fs::read_to_string(&output).unwrap());
        fs::write(dir.join("active.txt"), "off\n").unwrap();
        select_profile(&dir, &output).unwrap();
        assert!(!output.exists());
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn missing_or_invalid_selection_clears_stale_filters() {
        let dir = directory();
        let output = dir.join("control");
        fs::write(&output, "old filters").unwrap();
        select_profile(&dir, &output).unwrap();
        assert!(!output.exists());
        for selection in ["../other.txt", "sub/other.txt", "C:\\other.txt", "active.txt", "", "one.txt\ntwo.txt", "missing.txt"] {
            fs::write(dir.join("active.txt"), selection).unwrap();
            fs::write(&output, "old filters").unwrap();
            assert!(select_profile(&dir, &output).is_err(), "accepted {selection:?}");
            assert!(!output.exists(), "stale filters after {selection:?}");
        }
        fs::remove_dir_all(dir).unwrap();
    }
}

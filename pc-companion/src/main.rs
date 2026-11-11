//! PandaPointer, côté PC (prototype étape 1).
//!
//! Utilisation :
//!   pandapointer-pc              -> pilote la vraie souris
//!   pandapointer-pc --dry-run    -> mode test, affiche sans bouger la souris
//!   pandapointer-pc --port 5000  -> change le port (4210 par défaut)
//!
//! Étape 2 : en plus du déplacement et des boutons, le PC gère maintenant
//! le scroll (molette) et les touches de diaporama (suivant, précédent...).

mod cursor;
mod protocol;

use cursor::{Cursor, DryRun};
use protocol::{Button, Event, DEFAULT_PORT, MAX_SCROLL, MAX_STEP, MAX_ZOOM};
use std::net::{IpAddr, UdpSocket};
use std::time::Duration;

/// Si le téléphone disparaît bouton enfoncé (Wi-Fi coupé, appli fermée...),
/// on relâche tout après ce délai pour ne pas laisser la souris bloquée.
const SILENCE_TIMEOUT: Duration = Duration::from_secs(3);

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let dry_run = args.iter().any(|a| a == "--dry-run");
    let port = args
        .windows(2)
        .find(|w| w[0] == "--port")
        .and_then(|w| w[1].parse::<u16>().ok())
        .unwrap_or(DEFAULT_PORT);

    let mut cursor = make_cursor(dry_run);

    let socket = match UdpSocket::bind(("0.0.0.0", port)) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Impossible d'écouter sur le port {port} : {e}");
            eprintln!("Un autre programme l'utilise peut-être. Essaie --port 4211.");
            std::process::exit(1);
        }
    };
    socket
        .set_read_timeout(Some(SILENCE_TIMEOUT))
        .expect("réglage du délai d'attente impossible");

    println!("PandaPointer (PC) est prêt.");
    match local_ip() {
        Some(ip) => println!("Dans l'appli du téléphone, entre : {ip}  (port {port})"),
        None => println!("Port {port}. Trouve l'IP de ce PC avec la commande ipconfig."),
    }
    if dry_run {
        println!("Mode test : la souris ne bougera pas.");
    }
    println!("ATTENTION : ce prototype n'a pas de sécurité. À utiliser chez toi uniquement.");

    run(&socket, cursor.as_mut());
}

fn run(socket: &UdpSocket, cursor: &mut dyn Cursor) {
    let mut buf = [0u8; 64];
    let mut last_seq: Option<u16> = None;
    let mut left_down = false;
    let mut right_down = false;

    loop {
        match socket.recv_from(&mut buf) {
            Ok((len, _from)) => {
                let Some(packet) = protocol::parse(&buf[..len]) else {
                    continue; // ticket incompréhensible : on l'ignore
                };
                if !protocol::is_newer(last_seq, packet.seq) {
                    continue; // ticket en retard ou doublon
                }
                last_seq = Some(packet.seq);

                match packet.event {
                    Event::Move { dx, dy } => {
                        let dx = dx.clamp(-MAX_STEP, MAX_STEP) as i32;
                        let dy = dy.clamp(-MAX_STEP, MAX_STEP) as i32;
                        if dx != 0 || dy != 0 {
                            cursor.move_by(dx, dy);
                        }
                    }
                    Event::Button { button, pressed } => {
                        match button {
                            Button::Left => left_down = pressed,
                            Button::Right => right_down = pressed,
                        }
                        cursor.button(button, pressed);
                    }
                    Event::Click { button } => {
                        // Un clic complet termine aussi un éventuel bouton resté enfoncé.
                        match button {
                            Button::Left => left_down = false,
                            Button::Right => right_down = false,
                        }
                        cursor.click(button);
                    }
                    Event::Scroll { dx, dy } => {
                        let dx = dx.clamp(-MAX_SCROLL, MAX_SCROLL) as i32;
                        let dy = dy.clamp(-MAX_SCROLL, MAX_SCROLL) as i32;
                        if dx != 0 || dy != 0 {
                            cursor.scroll(dx, dy);
                        }
                    }
                    Event::Gesture(action) => cursor.gesture(action),
                    Event::Zoom { steps } => {
                        let steps = steps.clamp(-MAX_ZOOM, MAX_ZOOM) as i32;
                        if steps != 0 {
                            cursor.zoom(steps);
                        }
                    }
                    Event::Slide(action) => cursor.slide(action),
                }
            }
            // Silence prolongé : on relâche les boutons restés enfoncés.
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock || e.kind() == std::io::ErrorKind::TimedOut => {
                if left_down {
                    cursor.button(Button::Left, false);
                    left_down = false;
                }
                if right_down {
                    cursor.button(Button::Right, false);
                    right_down = false;
                }
            }
            Err(e) => {
                // Sous Windows, un paquet renvoyé à un téléphone absent peut
                // générer une erreur sans gravité : on continue.
                eprintln!("Erreur réseau ignorée : {e}");
            }
        }
    }
}

#[cfg(any(target_os = "windows", target_os = "macos"))]
fn make_cursor(dry_run: bool) -> Box<dyn Cursor> {
    if dry_run {
        return Box::new(DryRun);
    }
    match cursor::RealCursor::new() {
        Ok(c) => Box::new(c),
        Err(e) => {
            eprintln!("Impossible de piloter la souris : {e}");
            std::process::exit(1);
        }
    }
}

#[cfg(not(any(target_os = "windows", target_os = "macos")))]
fn make_cursor(_dry_run: bool) -> Box<dyn Cursor> {
    println!("(Cette plateforme ne pilote pas la vraie souris : mode test forcé.)");
    Box::new(DryRun)
}

/// Trouve l'adresse IP de ce PC sur le réseau local.
/// Astuce : on "prépare" un envoi vers l'extérieur (rien n'est réellement envoyé)
/// et on regarde quelle adresse locale le système choisirait.
fn local_ip() -> Option<IpAddr> {
    let socket = UdpSocket::bind("0.0.0.0:0").ok()?;
    socket.connect("8.8.8.8:80").ok()?;
    Some(socket.local_addr().ok()?.ip())
}

//! PandaPointer, côté PC (prototype étape 1).
//!
//! Utilisation :
//!   pandapointer-pc              -> pilote la vraie souris
//!   pandapointer-pc --dry-run    -> mode test, affiche sans bouger la souris
//!   pandapointer-pc --port 5000  -> change le port (4210 par défaut)
//!
//!   --no-tray                    -> (Windows) pas d'icône dans la barre des tâches, console seule
//!   --pair                       -> affiche un QR code d'appairage au démarrage
//!   --insecure                   -> sans chiffrement (tests uniquement)
//!
//! Étape 2 : en plus du déplacement et des boutons, le PC gère maintenant
//! le scroll (molette) et les touches de diaporama (suivant, précédent...).

// Version finale (cargo build --release) : pas de fenêtre noire, seulement l'icône du panda.
#![cfg_attr(all(windows, not(debug_assertions)), windows_subsystem = "windows")]

mod cursor;
mod laser;
mod protocol;
mod secure;
mod state;
#[cfg(windows)]
mod tray;

use cursor::{Cursor, DryRun};
use protocol::{Button, Event, DEFAULT_PORT, MAX_SCROLL, MAX_STEP, MAX_ZOOM};
use secure::{Auth, Opened, Store};
use state::{Command, Shared, Status};
use std::net::{IpAddr, SocketAddr, UdpSocket};
use std::sync::mpsc::{self, Receiver};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

/// Si le téléphone disparaît bouton enfoncé (Wi-Fi coupé, appli fermée...),
/// on relâche tout après ce délai pour ne pas laisser la souris bloquée.
const SILENCE_TIMEOUT: Duration = Duration::from_secs(3);

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let dry_run = args.iter().any(|a| a == "--dry-run");
    let insecure = args.iter().any(|a| a == "--insecure");
    let pair_now = args.iter().any(|a| a == "--pair");
    let arg_value = |name: &str| args.windows(2).find(|w| w[0] == name).map(|w| w[1].clone());
    let port = arg_value("--port")
        .and_then(|v| v.parse::<u16>().ok())
        .unwrap_or(DEFAULT_PORT);
    let data_dir = arg_value("--data-dir")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(secure::default_data_dir);

    let no_tray = args.iter().any(|a| a == "--no-tray");

    let socket = match UdpSocket::bind(("0.0.0.0", port)) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Impossible d'écouter sur le port {port} : {e}");
            eprintln!("Un autre programme l'utilise peut-être. Essaie --port 4211.");
            #[cfg(windows)]
            if !no_tray {
                tray::message_box("PandaPointer est déjà lancé (cherche le panda près de l'horloge).");
            }
            std::process::exit(1);
        }
    };
    // Petit délai d'attente : on en profite pour regarder les commandes du menu.
    socket
        .set_read_timeout(Some(Duration::from_millis(200)))
        .expect("réglage du délai d'attente impossible");

    let auth = if insecure {
        None
    } else {
        Some(Auth::new(Store::open(Some(data_dir.join("devices.txt")))))
    };

    println!("PandaPointer (PC) est prêt sur le port {port}.");
    if dry_run {
        println!("Mode test : la souris ne bougera pas.");
    }
    match &auth {
        None => println!("ATTENTION : mode --insecure, aucune protection. Pour tes tests uniquement."),
        Some(a) if a.store.devices.is_empty() => {
            println!("Aucun téléphone appairé : lance avec --pair pour afficher un QR code.");
        }
        Some(a) => println!("{} téléphone(s) appairé(s).", a.store.devices.len()),
    }
    if let Some(ip) = local_ip() {
        println!("Adresse de ce PC : {ip}");
    }

    let (cmd_tx, cmd_rx) = mpsc::channel();
    let status: Shared = Arc::new(Mutex::new(Status::default()));
    if pair_now && !insecure {
        let _ = cmd_tx.send(Command::Pair);
    }

    // Windows : le réseau tourne en tâche de fond, le fil principal affiche l'icône.
    #[cfg(windows)]
    if !no_tray {
        let first_run = auth.as_ref().is_some_and(|a| a.store.devices.is_empty());
        if first_run {
            let _ = cmd_tx.send(Command::Pair); // premier lancement : on montre tout de suite le QR code
        }
        let net_status = status.clone();
        std::thread::spawn(move || {
            let mut cursor = make_cursor(dry_run);
            run(&socket, cursor.as_mut(), auth, &cmd_rx, &net_status, port);
        });
        tray::run(cmd_tx, status, first_run);
        std::process::exit(0);
    }

    let _keep_sender_alive = cmd_tx;
    let mut cursor = make_cursor(dry_run);
    run(&socket, cursor.as_mut(), auth, &cmd_rx, &status, port);
}

/// Nom du PC, montré dans l'appli du téléphone quand elle cherche (« PC_PANDA »...).
fn pc_name() -> String {
    std::env::var("COMPUTERNAME")
        .or_else(|_| std::env::var("HOSTNAME"))
        .unwrap_or_else(|_| "PC".to_string())
}

/// L'état de la souris côté PC (boutons enfoncés, laser...).
#[derive(Default)]
struct Held {
    left: bool,
    right: bool,
    laser: bool, // laser allumé : les mouvements le déplacent, pas le curseur
}

impl Held {
    fn release_all(&mut self, cursor: &mut dyn Cursor) {
        if self.left {
            cursor.button(Button::Left, false);
            self.left = false;
        }
        if self.right {
            cursor.button(Button::Right, false);
            self.right = false;
        }
        // Le téléphone ne donne plus signe de vie : on éteint le laser.
        if self.laser {
            cursor.laser(false);
            self.laser = false;
        }
    }
}

fn refresh_devices(auth: &Auth, status: &Shared) {
    status.lock().unwrap().devices = auth.store.devices.iter().map(|d| (d.id, d.name.clone())).collect();
}

fn run(
    socket: &UdpSocket,
    cursor: &mut dyn Cursor,
    mut auth: Option<Auth>,
    commands: &Receiver<Command>,
    status: &Shared,
    port: u16,
) {
    let here = protocol::here_packet(&pc_name());
    let mut buf = [0u8; 128];
    let mut last_seq: Option<u16> = None;
    let mut held = Held::default();
    let mut last_heard = Instant::now();
    if let Some(a) = &auth {
        refresh_devices(a, status);
    }

    loop {
        // Commandes venues du menu (appairer, oublier un téléphone).
        while let Ok(cmd) = commands.try_recv() {
            let Some(a) = auth.as_mut() else { continue };
            match cmd {
                Command::Pair => {
                    let dev = a.store.start_pairing();
                    let url = secure::pair_url(&dev, &pc_name(), port);
                    println!("\nScanne ce QR code avec l'appli PandaPointer (valable 5 minutes) :\n");
                    if let Some(qr) = secure::qr_text(&url) {
                        println!("{qr}");
                    }
                    println!("Lien : {url}\n");
                    status.lock().unwrap().pair_url = Some(url);
                }
                Command::Forget(id) => {
                    a.store.forget(&id);
                    refresh_devices(a, status);
                }
            }
        }

        match socket.recv_from(&mut buf) {
            Ok((len, from)) => {
                let data = &buf[..len];
                let event = match classify(data, from, &mut auth, socket, &here, status, &mut last_seq) {
                    Some(ev) => ev,
                    None => continue,
                };
                last_heard = Instant::now();
                apply(event, cursor, &mut held, &mut auth, socket, from);
            }
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock || e.kind() == std::io::ErrorKind::TimedOut => {}
            Err(e) => {
                // Sous Windows, un paquet renvoyé à un téléphone absent peut
                // générer une erreur sans gravité : on continue.
                eprintln!("Erreur réseau ignorée : {e}");
            }
        }

        // Silence prolongé : on relâche les boutons restés enfoncés.
        if last_heard.elapsed() > SILENCE_TIMEOUT {
            held.release_all(cursor);
        }
    }
}

/// Décide ce qu'on fait d'un datagramme : réponses directes (recherche, authentification),
/// déchiffrement, sinon renvoie l'événement à appliquer. None = rien à faire.
fn classify(
    data: &[u8],
    from: SocketAddr,
    auth: &mut Option<Auth>,
    socket: &UdpSocket,
    here: &[u8],
    status: &Shared,
    last_seq: &mut Option<u16>,
) -> Option<Event> {
    // « Y a-t-il un PC ici ? » : on répond tout de suite, sans authentification (le nom du PC
    // n'est pas un secret, et ça permet à l'appli de le trouver sur le réseau).
    if protocol::parse(data).is_some_and(|p| p.event == Event::Hello) {
        let _ = socket.send_to(here, from);
        return None;
    }

    let Some(a) = auth.as_mut() else {
        // Mode --insecure : tickets en clair, comme avant.
        let packet = protocol::parse(data)?;
        if !protocol::is_newer(*last_seq, packet.seq) {
            return None; // ticket en retard ou doublon
        }
        *last_seq = Some(packet.seq);
        return Some(packet.event);
    };

    match data.first().copied() {
        Some(secure::TYPE_AUTH_REQ) => {
            if let Some(reply) = a.handle_auth_req(from, data) {
                let _ = socket.send_to(&reply, from);
            }
            *last_seq = None; // nouvelle session : on repart des numéros de départ
            None
        }
        Some(secure::TYPE_SEALED) => match a.open(from, data) {
            Opened::Packet { inner, device, newly_paired } => {
                let name = a.device_name(&device);
                status.lock().unwrap().phone = Some((name, Instant::now()));
                if let Some(n) = newly_paired {
                    println!("Téléphone appairé : {n}");
                    status.lock().unwrap().notice = Some(format!("{n} est appairé"));
                    refresh_devices(a, status);
                }
                let packet = protocol::parse(&inner)?;
                if !protocol::is_newer(*last_seq, packet.seq) {
                    return None;
                }
                *last_seq = Some(packet.seq);
                Some(packet.event)
            }
            Opened::Dropped => None,
        },
        _ => None, // ticket en clair alors que la protection est active : refusé
    }
}

fn apply(
    event: Event,
    cursor: &mut dyn Cursor,
    held: &mut Held,
    auth: &mut Option<Auth>,
    socket: &UdpSocket,
    from: SocketAddr,
) {
    match event {
        Event::Move { dx, dy } => {
            let dx = dx.clamp(-MAX_STEP, MAX_STEP) as i32;
            let dy = dy.clamp(-MAX_STEP, MAX_STEP) as i32;
            if dx != 0 || dy != 0 {
                if held.laser {
                    cursor.laser_move_by(dx, dy);
                } else {
                    cursor.move_by(dx, dy);
                }
            }
        }
        Event::Button { button, pressed } => {
            match button {
                Button::Left => held.left = pressed,
                Button::Right => held.right = pressed,
            }
            cursor.button(button, pressed);
        }
        Event::Click { button } => {
            // Un clic complet termine aussi un éventuel bouton resté enfoncé.
            match button {
                Button::Left => held.left = false,
                Button::Right => held.right = false,
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
        Event::Hello => {} // déjà traité plus haut
        Event::Ping => {
            // « Tu es toujours là ? » : on répond (chiffré) pour que le téléphone sache que la liaison vit.
            if let Some(a) = auth.as_mut() {
                if let Some(pong) = a.seal_for(from, &protocol::PONG_PACKET) {
                    let _ = socket.send_to(&pong, from);
                }
            }
        }
        Event::Laser { on } => {
            // Le téléphone renvoie « allumé » chaque seconde pour dire qu'il est toujours là.
            // Si le laser est déjà allumé, on ne fait rien : le rallumer le replacerait
            // sur le curseur de la souris.
            if on != held.laser {
                held.laser = on;
                cursor.laser(on);
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

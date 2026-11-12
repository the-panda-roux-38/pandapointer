//! Sécurité : appairage du téléphone et chiffrement des tickets.
//!
//! Image : un badge d'accès d'immeuble.
//!   - L'APPAIRAGE (une seule fois) : le PC fabrique un badge (une clé secrète de 32 octets) et le
//!     montre sous forme de QR code. Le téléphone le scanne et le garde. C'est le seul moment où
//!     la clé voyage : par la caméra, pas par le Wi-Fi.
//!   - À CHAQUE SESSION : le téléphone dit « c'est moi » (AUTH_REQ), le PC répond par un défi
//!     aléatoire (AUTH_OK) signé avec la clé. Les deux calculent une clé de session à partir de la
//!     clé secrète et des deux nombres aléatoires. Un ticket enregistré hier ne marche donc plus
//!     aujourd'hui (la clé de session est différente) : impossible de « rejouer » un ancien ticket.
//!   - Ensuite, chaque ticket est chiffré et signé (ChaCha20-Poly1305) : sans la clé, on ne peut ni
//!     lire un ticket, ni en fabriquer, ni en modifier un.
//!
//! Formats (octets, little endian) :
//!   AUTH_REQ  [10, 0, 0] + id appareil (8) + nombre aléatoire du téléphone (8)      = 19 octets
//!   AUTH_OK   [11, 0, 0] + nombre aléatoire du PC (16) + signature (16)             = 35 octets
//!   AUTH_NO   [12, 0, 0]  (« je ne te connais pas » : appairage à refaire)           =  3 octets
//!   SCELLÉ    [0xE1] + compteur (u64) + ticket chiffré + signature (16)
//!   Le ticket chiffré est un ticket normal (voir protocol.rs). Compteur strictement croissant.
//!   Clé de session = HMAC-SHA256(clé, "pp-sess" + nombre téléphone + nombre PC).
//!   Signature AUTH_OK = 16 premiers octets de HMAC-SHA256(clé, "pp-srv" + nb téléphone + nb PC + id).
//!   Nonce ChaCha20 (12 octets) = [sens, 0, 0, 0] + compteur (u64) ; sens 0 = téléphone→PC, 1 = PC→téléphone.
//!   Données authentifiées (AAD) = l'octet 0xE1.
//!
//! Mêmes octets décrits côté téléphone dans `mobile/lib/secure.dart` : les deux restent d'accord
//! grâce à des vecteurs de test communs.

use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use std::collections::HashMap;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::time::{Duration, Instant};

pub const TYPE_AUTH_REQ: u8 = 10;
pub const TYPE_AUTH_OK: u8 = 11;
pub const TYPE_AUTH_NO: u8 = 12;
pub const TYPE_SEALED: u8 = 0xE1;

/// Durée pendant laquelle un QR code d'appairage reste utilisable.
pub const PAIR_WINDOW: Duration = Duration::from_secs(300);

type HmacSha256 = Hmac<Sha256>;

pub type DeviceId = [u8; 8];

#[derive(Clone)]
pub struct Device {
    pub id: DeviceId,
    pub key: [u8; 32],
    pub name: String,
}

pub fn random_bytes<const N: usize>() -> [u8; N] {
    let mut b = [0u8; N];
    getrandom::getrandom(&mut b).expect("pas de source aléatoire sur ce système");
    b
}

pub fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

pub fn unhex(s: &str) -> Option<Vec<u8>> {
    if s.len() % 2 != 0 || !s.is_ascii() {
        return None;
    }
    (0..s.len() / 2)
        .map(|i| u8::from_str_radix(&s[2 * i..2 * i + 2], 16).ok())
        .collect()
}

fn hmac(key: &[u8], parts: &[&[u8]]) -> [u8; 32] {
    let mut m = <HmacSha256 as Mac>::new_from_slice(key).expect("clé HMAC");
    for p in parts {
        m.update(p);
    }
    m.finalize().into_bytes().into()
}

pub fn session_key(key: &[u8; 32], cn: &[u8; 8], sn: &[u8; 16]) -> [u8; 32] {
    hmac(key, &[b"pp-sess", cn, sn])
}

pub fn server_tag(key: &[u8; 32], cn: &[u8; 8], sn: &[u8; 16], id: &DeviceId) -> [u8; 16] {
    let full = hmac(key, &[b"pp-srv", cn, sn, id]);
    let mut t = [0u8; 16];
    t.copy_from_slice(&full[..16]);
    t
}

fn nonce(dir: u8, counter: u64) -> [u8; 12] {
    let mut n = [0u8; 12];
    n[0] = dir;
    n[4..].copy_from_slice(&counter.to_le_bytes());
    n
}

/// Chiffre un ticket. `dir` : 0 = téléphone→PC, 1 = PC→téléphone.
pub fn seal(session: &[u8; 32], dir: u8, counter: u64, inner: &[u8]) -> Vec<u8> {
    let cipher = ChaCha20Poly1305::new(Key::from_slice(session));
    let n = nonce(dir, counter);
    let ct = cipher
        .encrypt(Nonce::from_slice(&n), Payload { msg: inner, aad: &[TYPE_SEALED] })
        .expect("chiffrement");
    let mut out = Vec::with_capacity(9 + ct.len());
    out.push(TYPE_SEALED);
    out.extend_from_slice(&counter.to_le_bytes());
    out.extend_from_slice(&ct);
    out
}

/// Déchiffre un ticket scellé : renvoie (compteur, ticket) si la signature est bonne.
pub fn unseal(session: &[u8; 32], dir: u8, data: &[u8]) -> Option<(u64, Vec<u8>)> {
    if data.len() < 9 + 16 || data[0] != TYPE_SEALED {
        return None;
    }
    let counter = u64::from_le_bytes(data[1..9].try_into().ok()?);
    let cipher = ChaCha20Poly1305::new(Key::from_slice(session));
    let n = nonce(dir, counter);
    let inner = cipher
        .decrypt(Nonce::from_slice(&n), Payload { msg: &data[9..], aad: &[TYPE_SEALED] })
        .ok()?;
    Some((counter, inner))
}

/// Lien d'appairage placé dans le QR code.
pub fn pair_url(dev: &Device, pc_name: &str, port: u16, ip: Option<std::net::IpAddr>) -> String {
    let mut name = String::new();
    for b in pc_name.bytes() {
        if b.is_ascii_alphanumeric() || b == b'-' || b == b'_' || b == b'.' {
            name.push(b as char);
        } else {
            name.push_str(&format!("%{b:02X}"));
        }
    }
    let mut url = format!("pandapointer://pair?v=1&id={}&k={}&n={}&p={}", hex(&dev.id), hex(&dev.key), name, port);
    // Adresse du PC : le téléphone s'y connecte directement, sans avoir à chercher.
    if let Some(std::net::IpAddr::V4(a)) = ip {
        url.push_str(&format!("&a={a}"));
    }
    url
}

/// Le QR code en caractères (pour la console), 2 lignes de pixels par ligne de texte.
pub fn qr_text(url: &str) -> Option<String> {
    let code = qrcode::QrCode::new(url.as_bytes()).ok()?;
    let w = code.width();
    let quiet = 2usize;
    let size = w + 2 * quiet;
    let dark = |x: usize, y: usize| -> bool {
        if x < quiet || y < quiet || x >= w + quiet || y >= w + quiet {
            return false;
        }
        code[(x - quiet, y - quiet)] == qrcode::Color::Dark
    };
    // Fond clair, modules sombres : le terminal est souvent sombre, on inverse donc (« █ » = clair).
    let mut out = String::new();
    let mut y = 0;
    while y < size {
        for x in 0..size {
            let top = !dark(x, y);
            let bottom = if y + 1 < size { !dark(x, y + 1) } else { true };
            out.push(match (top, bottom) {
                (true, true) => '█',
                (true, false) => '▀',
                (false, true) => '▄',
                (false, false) => ' ',
            });
        }
        out.push('\n');
        y += 2;
    }
    Some(out)
}

/// Le QR code en image BMP noir et blanc (pour l'ouvrir dans le visualiseur d'images de Windows).
pub fn qr_bmp(url: &str) -> Option<Vec<u8>> {
    let code = qrcode::QrCode::new(url.as_bytes()).ok()?;
    let w = code.width();
    let quiet = 4usize;
    let scale = 10usize;
    let side = (w + 2 * quiet) * scale;
    let row_bytes = (side * 3).div_ceil(4) * 4;
    let mut px = vec![0xFFu8; row_bytes * side];
    for y in 0..side {
        for x in 0..side {
            let (mx, my) = (x / scale, y / scale);
            let dark = mx >= quiet
                && my >= quiet
                && mx < w + quiet
                && my < w + quiet
                && code[(mx - quiet, my - quiet)] == qrcode::Color::Dark;
            if dark {
                // BMP stocke les lignes de bas en haut
                let row = side - 1 - y;
                let o = row * row_bytes + x * 3;
                px[o] = 0x10;
                px[o + 1] = 0x10;
                px[o + 2] = 0x10;
            }
        }
    }
    let size = 54 + px.len();
    let mut f = Vec::with_capacity(size);
    f.extend_from_slice(b"BM");
    f.extend_from_slice(&(size as u32).to_le_bytes());
    f.extend_from_slice(&[0, 0, 0, 0]);
    f.extend_from_slice(&54u32.to_le_bytes());
    f.extend_from_slice(&40u32.to_le_bytes());
    f.extend_from_slice(&(side as i32).to_le_bytes());
    f.extend_from_slice(&(side as i32).to_le_bytes());
    f.extend_from_slice(&1u16.to_le_bytes());
    f.extend_from_slice(&24u16.to_le_bytes());
    f.extend_from_slice(&[0; 4]);
    f.extend_from_slice(&(px.len() as u32).to_le_bytes());
    f.extend_from_slice(&[0x13, 0x0B, 0, 0, 0x13, 0x0B, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    f.extend_from_slice(&px);
    Some(f)
}

// ---------------------------------------------------------------------------
// Carnet des appareils de confiance
// ---------------------------------------------------------------------------

pub fn default_data_dir() -> PathBuf {
    if let Ok(appdata) = std::env::var("APPDATA") {
        return PathBuf::from(appdata).join("PandaPointer");
    }
    if let Ok(home) = std::env::var("HOME") {
        return PathBuf::from(home).join(".pandapointer");
    }
    PathBuf::from(".pandapointer")
}

/// Les appareils appairés (sauvegardés dans un fichier) et les appairages en attente
/// (en mémoire seulement : un QR non utilisé expire et disparaît).
pub struct Store {
    path: Option<PathBuf>,
    pub devices: Vec<Device>,
    pending: Vec<(Device, Instant)>,
}

impl Store {
    /// `path` = None : carnet en mémoire seulement (tests).
    pub fn open(path: Option<PathBuf>) -> Store {
        let mut devices = Vec::new();
        if let Some(p) = &path {
            if let Ok(text) = std::fs::read_to_string(p) {
                for line in text.lines() {
                    let mut it = line.splitn(3, ' ');
                    let (Some(id), Some(key), name) = (it.next(), it.next(), it.next()) else {
                        continue;
                    };
                    let (Some(id), Some(key)) = (unhex(id), unhex(key)) else { continue };
                    let (Ok(id), Ok(key)) = (DeviceId::try_from(id), <[u8; 32]>::try_from(key)) else {
                        continue;
                    };
                    devices.push(Device { id, key, name: name.unwrap_or("Téléphone").to_string() });
                }
            }
        }
        Store { path, devices, pending: Vec::new() }
    }

    fn save(&self) {
        let Some(p) = &self.path else { return };
        if let Some(dir) = p.parent() {
            let _ = std::fs::create_dir_all(dir);
        }
        let text: String = self
            .devices
            .iter()
            .map(|d| format!("{} {} {}\n", hex(&d.id), hex(&d.key), d.name.replace('\n', " ")))
            .collect();
        let tmp = p.with_extension("tmp");
        if std::fs::write(&tmp, text).is_ok() {
            let _ = std::fs::rename(&tmp, p);
        }
    }

    /// Prépare un nouvel appairage : une clé fraîche, valable `PAIR_WINDOW`.
    pub fn start_pairing(&mut self) -> Device {
        self.pending.retain(|(_, t)| t.elapsed() < PAIR_WINDOW);
        let dev = Device {
            id: random_bytes::<8>(),
            key: random_bytes::<32>(),
            name: format!("Téléphone {}", self.devices.len() + 1),
        };
        self.pending.push((dev.clone(), Instant::now()));
        dev
    }

    pub fn forget(&mut self, id: &DeviceId) {
        self.devices.retain(|d| &d.id != id);
        self.save();
    }

    fn find(&self, id: &DeviceId) -> Option<(Device, bool)> {
        if let Some(d) = self.devices.iter().find(|d| &d.id == id) {
            return Some((d.clone(), false));
        }
        self.pending
            .iter()
            .find(|(d, t)| &d.id == id && t.elapsed() < PAIR_WINDOW)
            .map(|(d, _)| (d.clone(), true))
    }

    /// Un appairage en attente devient définitif au premier ticket authentique reçu.
    fn confirm(&mut self, id: &DeviceId) -> Option<String> {
        let pos = self.pending.iter().position(|(d, _)| &d.id == id)?;
        let (dev, _) = self.pending.remove(pos);
        let name = dev.name.clone();
        self.devices.push(dev);
        self.save();
        Some(name)
    }
}

// ---------------------------------------------------------------------------
// Sessions
// ---------------------------------------------------------------------------

struct Session {
    device: DeviceId,
    pending: bool,
    key: [u8; 32],
    last_counter: Option<u64>,
    out_counter: u64,
}

pub enum Opened {
    /// Ticket authentique : (ticket déchiffré, appareil, nom de l'appareil s'il vient d'être appairé)
    Packet { inner: Vec<u8>, device: DeviceId, newly_paired: Option<String> },
    /// Ticket refusé (pas de session, mauvaise signature, rejeu...)
    Dropped,
}

pub struct Auth {
    pub store: Store,
    sessions: HashMap<SocketAddr, Session>,
}

impl Auth {
    pub fn new(store: Store) -> Auth {
        Auth { store, sessions: HashMap::new() }
    }

    /// Traite un AUTH_REQ : renvoie la réponse à envoyer (AUTH_OK ou AUTH_NO).
    pub fn handle_auth_req(&mut self, from: SocketAddr, data: &[u8]) -> Option<Vec<u8>> {
        if data.len() != 19 || data[0] != TYPE_AUTH_REQ {
            return None;
        }
        let id: DeviceId = data[3..11].try_into().ok()?;
        let cn: [u8; 8] = data[11..19].try_into().ok()?;
        let Some((dev, pending)) = self.store.find(&id) else {
            return Some(vec![TYPE_AUTH_NO, 0, 0]);
        };
        let sn = random_bytes::<16>();
        self.sessions.insert(
            from,
            Session {
                device: id,
                pending,
                key: session_key(&dev.key, &cn, &sn),
                last_counter: None,
                out_counter: 0,
            },
        );
        let mut out = vec![TYPE_AUTH_OK, 0, 0];
        out.extend_from_slice(&sn);
        out.extend_from_slice(&server_tag(&dev.key, &cn, &sn, &id));
        Some(out)
    }

    pub fn open(&mut self, from: SocketAddr, data: &[u8]) -> Opened {
        let Some(s) = self.sessions.get_mut(&from) else { return Opened::Dropped };
        let Some((counter, inner)) = unseal(&s.key, 0, data) else { return Opened::Dropped };
        if s.last_counter.is_some_and(|l| counter <= l) {
            return Opened::Dropped; // rejeu ou ticket en retard
        }
        s.last_counter = Some(counter);
        let device = s.device;
        let mut newly_paired = None;
        if s.pending {
            s.pending = false;
            newly_paired = self.store.confirm(&device);
        }
        Opened::Packet { inner, device, newly_paired }
    }

    /// Chiffre une réponse du PC pour ce téléphone (s'il a une session ouverte).
    pub fn seal_for(&mut self, to: SocketAddr, inner: &[u8]) -> Option<Vec<u8>> {
        let s = self.sessions.get_mut(&to)?;
        s.out_counter += 1;
        Some(seal(&s.key, 1, s.out_counter, inner))
    }


    pub fn device_name(&self, id: &DeviceId) -> String {
        self.store
            .devices
            .iter()
            .find(|d| &d.id == id)
            .map(|d| d.name.clone())
            .unwrap_or_else(|| "Téléphone".into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const KEY: [u8; 32] = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26,
        27, 28, 29, 30, 31,
    ];
    const ID: DeviceId = [1, 2, 3, 4, 5, 6, 7, 8];
    const CN: [u8; 8] = [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17];
    const SN: [u8; 16] = [
        0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f,
    ];

    /// Vecteurs communs avec le téléphone (mobile/test/secure_test.dart).
    #[test]
    fn shared_vectors_with_phone() {
        let sk = session_key(&KEY, &CN, &SN);
        let tag = server_tag(&KEY, &CN, &SN, &ID);
        let sealed = seal(&sk, 0, 1, &[4, 0, 0, 1]);
        assert_eq!(hex(&sk), VECTOR_SK);
        assert_eq!(hex(&tag), VECTOR_TAG);
        assert_eq!(hex(&sealed), VECTOR_SEALED);
    }

    const VECTOR_SK: &str = "09c8e6305a164772a14078ed6d78e7e29290b4dbc9798a9313b3c7ac2f8ed1e6";
    const VECTOR_TAG: &str = "d9f908ee688cca7d11a858714390535a";
    const VECTOR_SEALED: &str = "e10100000000000000a3a4e278e4770513e97bd377297f3c2f8be80f07";

    #[test]
    fn seal_roundtrip_and_tamper() {
        let sk = session_key(&KEY, &CN, &SN);
        let mut s = seal(&sk, 0, 7, &[1, 0, 0, 5, 0, 250, 255]);
        assert_eq!(unseal(&sk, 0, &s), Some((7, vec![1, 0, 0, 5, 0, 250, 255])));
        assert!(unseal(&sk, 1, &s).is_none(), "mauvais sens refusé");
        let last = s.len() - 1;
        s[last] ^= 1;
        assert!(unseal(&sk, 0, &s).is_none(), "ticket modifié refusé");
        assert!(unseal(&[9; 32], 0, &seal(&sk, 0, 1, &[1])).is_none(), "mauvaise clé refusée");
    }

    fn addr(p: u16) -> SocketAddr {
        format!("192.168.43.2:{p}").parse().unwrap()
    }

    fn client_req(id: &DeviceId, cn: &[u8; 8]) -> Vec<u8> {
        let mut r = vec![TYPE_AUTH_REQ, 0, 0];
        r.extend_from_slice(id);
        r.extend_from_slice(cn);
        r
    }

    #[test]
    fn full_pairing_and_session_flow() {
        let mut auth = Auth::new(Store::open(None));
        // inconnu : refusé
        let reply = auth.handle_auth_req(addr(1), &client_req(&ID, &CN)).unwrap();
        assert_eq!(reply, vec![TYPE_AUTH_NO, 0, 0]);

        // appairage en attente
        let dev = auth.store.start_pairing();
        let reply = auth.handle_auth_req(addr(1), &client_req(&dev.id, &CN)).unwrap();
        assert_eq!(reply[0], TYPE_AUTH_OK);
        let sn: [u8; 16] = reply[3..19].try_into().unwrap();
        // le téléphone vérifie que le PC connaît bien la clé
        assert_eq!(&reply[19..35], &server_tag(&dev.key, &CN, &sn, &dev.id));
        let sk = session_key(&dev.key, &CN, &sn);

        // 1er ticket authentique : appairage confirmé
        let t1 = seal(&sk, 0, 1, &[4, 0, 0, 1]);
        match auth.open(addr(1), &t1) {
            Opened::Packet { inner, newly_paired, .. } => {
                assert_eq!(inner, vec![4, 0, 0, 1]);
                assert!(newly_paired.is_some());
            }
            _ => panic!("ticket refusé"),
        }
        assert_eq!(auth.store.devices.len(), 1);
        // rejeu du même ticket : refusé
        assert!(matches!(auth.open(addr(1), &t1), Opened::Dropped));
        // ticket suivant : accepté, plus d'« appairage » signalé
        let t2 = seal(&sk, 0, 2, &[4, 0, 0, 2]);
        assert!(matches!(auth.open(addr(1), &t2), Opened::Packet { newly_paired: None, .. }));
        // un autre expéditeur ne peut pas réutiliser la session
        assert!(matches!(auth.open(addr(2), &seal(&sk, 0, 3, &[1])), Opened::Dropped));
        // nouvelle session : l'ancien ticket ne marche plus
        let reply = auth.handle_auth_req(addr(1), &client_req(&dev.id, &CN)).unwrap();
        let sn2: [u8; 16] = reply[3..19].try_into().unwrap();
        assert_ne!(sn, sn2);
        assert!(matches!(auth.open(addr(1), &seal(&sk, 0, 9, &[1])), Opened::Dropped));
        // le PC répond chiffré, le téléphone peut lire
        let pong = auth.seal_for(addr(1), &[14, 0, 0]).unwrap();
        let sk2 = session_key(&dev.key, &CN, &sn2);
        assert_eq!(unseal(&sk2, 1, &pong), Some((1, vec![14, 0, 0])));
    }

    #[test]
    fn pair_url_and_qr() {
        let dev = Device { id: ID, key: KEY, name: "x".into() };
        let url = pair_url(&dev, "PC PANDA é", 4210, None);
        assert!(url.starts_with("pandapointer://pair?v=1&id=0102030405060708&k=000102"));
        assert!(url.ends_with("&n=PC%20PANDA%20%C3%A9&p=4210"));
        let with_ip = pair_url(&dev, "x", 4210, Some("192.168.1.42".parse().unwrap()));
        assert!(with_ip.ends_with("&p=4210&a=192.168.1.42"));
        assert!(qr_text(&url).unwrap().lines().count() > 10);
        let bmp = qr_bmp(&url).unwrap();
        assert_eq!(&bmp[..2], b"BM");
        assert_eq!(u32::from_le_bytes(bmp[2..6].try_into().unwrap()) as usize, bmp.len());
    }

    #[test]
    fn store_roundtrip_on_disk() {
        let dir = std::env::temp_dir().join(format!("pp-test-{}", hex(&random_bytes::<4>())));
        let path = dir.join("devices.txt");
        let mut s = Store::open(Some(path.clone()));
        let d = s.start_pairing();
        s.pending.clear();
        s.devices.push(d.clone());
        s.save();
        let s2 = Store::open(Some(path));
        assert_eq!(s2.devices.len(), 1);
        assert_eq!(s2.devices[0].id, d.id);
        assert_eq!(s2.devices[0].key, d.key);
        let _ = std::fs::remove_dir_all(dir);
    }
}

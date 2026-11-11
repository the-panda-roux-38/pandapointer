//! Icône dans la barre des tâches de Windows + son menu.
//!
//! Le menu : statut, « Appairer un téléphone », « Téléphones appairés », « Lancer avec
//! Windows », « Quitter ». Aucune bibliothèque d'interface : on parle directement à Windows
//! (comme pour le laser), ce qui garde le programme petit.
//!
//! Le réseau tourne dans un autre fil d'exécution ; on se parle par `state` (commandes + statut).

use crate::secure::{self, DeviceId};
use crate::state::{Command, Shared};
use std::cell::RefCell;
use std::path::PathBuf;
use std::ptr::{null, null_mut};
use std::sync::mpsc::Sender;
use std::time::Duration;
use windows_sys::Win32::Foundation::{HWND, LPARAM, LRESULT, POINT, WPARAM};
use windows_sys::Win32::System::LibraryLoader::GetModuleHandleW;
use windows_sys::Win32::System::Registry::{
    RegCloseKey, RegCreateKeyExW, RegDeleteValueW, RegQueryValueExW, RegSetValueExW, HKEY,
    HKEY_CURRENT_USER, KEY_READ, KEY_WRITE, REG_OPTION_NON_VOLATILE, REG_SZ,
};
use windows_sys::Win32::UI::Shell::{
    ShellExecuteW, Shell_NotifyIconW, NIF_ICON, NIF_INFO, NIF_MESSAGE, NIF_TIP, NIIF_INFO,
    NIM_ADD, NIM_DELETE, NIM_MODIFY, NOTIFYICONDATAW,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    AppendMenuW, CreateIcon, CreatePopupMenu, CreateWindowExW, DefWindowProcW, DestroyMenu,
    DispatchMessageW, GetCursorPos, GetMessageW, MessageBoxW, PostMessageW, PostQuitMessage,
    RegisterClassExW, RegisterWindowMessageW, SetForegroundWindow, SetTimer, TrackPopupMenu,
    TranslateMessage, MB_ICONINFORMATION, MB_OK, MF_CHECKED, MF_GRAYED, MF_POPUP, MF_SEPARATOR,
    MF_STRING, MSG, SW_SHOWNORMAL, TPM_NONOTIFY, TPM_RETURNCMD, TPM_RIGHTBUTTON, WM_APP,
    WM_LBUTTONUP, WM_NULL, WM_RBUTTONUP, WM_TIMER, WNDCLASSEXW,
};

/// Image 32x32 de l'icône (R, V, B, A), dessinée par `assets/make_icon.py`.
const ICON_RGBA: &[u8] = include_bytes!("../assets/tray32.rgba");

const WM_TRAY: u32 = WM_APP + 1;
const TIMER_ID: usize = 1;

const ID_PAIR: usize = 1;
const ID_AUTOSTART: usize = 2;
const ID_QUIT: usize = 3;
const ID_FORGET_BASE: usize = 100;

const RUN_KEY: &str = "Software\\Microsoft\\Windows\\CurrentVersion\\Run";
const RUN_VALUE: &str = "PandaPointer";

/// Un téléphone vu depuis moins de ce délai compte comme « connecté ».
const ONLINE_WINDOW: Duration = Duration::from_secs(4);

struct Ctx {
    commands: Sender<Command>,
    status: Shared,
    taskbar_created: u32,
    last_qr: Option<PathBuf>,
}

thread_local! {
    static CTX: RefCell<Option<Ctx>> = const { RefCell::new(None) };
}

fn wide(s: &str) -> Vec<u16> {
    s.encode_utf16().chain(std::iter::once(0)).collect()
}

fn copy_wide<const N: usize>(dst: &mut [u16; N], s: &str) {
    let mut i = 0;
    for c in s.encode_utf16().take(N - 1) {
        dst[i] = c;
        i += 1;
    }
    dst[i] = 0;
}

/// Boîte de message simple (utilisée quand le programme est déjà lancé, par exemple).
pub fn message_box(text: &str) {
    unsafe {
        MessageBoxW(null_mut(), wide(text).as_ptr(), wide("PandaPointer").as_ptr(), MB_OK | MB_ICONINFORMATION);
    }
}

/// Dessine l'icône du panda roux.
fn make_icon() -> isize {
    // Windows veut B, V, R, A ; notre image est en R, V, B, A.
    let mut xor = Vec::with_capacity(ICON_RGBA.len());
    for px in ICON_RGBA.chunks_exact(4) {
        xor.extend_from_slice(&[px[2], px[1], px[0], px[3]]);
    }
    let and = vec![0u8; 32 * 32 / 8];
    unsafe { CreateIcon(GetModuleHandleW(null()), 32, 32, 1, 32, and.as_ptr(), xor.as_ptr()) as isize }
}

fn notify(hwnd: HWND, msg: u32, tip: &str, balloon: Option<(&str, &str)>) {
    unsafe {
        let mut nid: NOTIFYICONDATAW = std::mem::zeroed();
        nid.cbSize = std::mem::size_of::<NOTIFYICONDATAW>() as u32;
        nid.hWnd = hwnd;
        nid.uID = 1;
        nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
        nid.uCallbackMessage = WM_TRAY;
        nid.hIcon = make_icon() as _;
        copy_wide(&mut nid.szTip, tip);
        if let Some((title, text)) = balloon {
            nid.uFlags |= NIF_INFO;
            nid.dwInfoFlags = NIIF_INFO;
            copy_wide(&mut nid.szInfoTitle, title);
            copy_wide(&mut nid.szInfo, text);
        }
        Shell_NotifyIconW(msg, &nid);
    }
}

fn balloon(hwnd: HWND, title: &str, text: &str) {
    notify(hwnd, NIM_MODIFY, "PandaPointer", Some((title, text)));
}

// ---------------------------------------------------------------------------
// « Lancer avec Windows » : une ligne dans la base de registre de l'utilisateur.
// ---------------------------------------------------------------------------

fn open_run_key() -> Option<HKEY> {
    unsafe {
        let mut key: HKEY = null_mut();
        let rc = RegCreateKeyExW(
            HKEY_CURRENT_USER,
            wide(RUN_KEY).as_ptr(),
            0,
            null(),
            REG_OPTION_NON_VOLATILE,
            KEY_READ | KEY_WRITE,
            null(),
            &mut key,
            null_mut(),
        );
        if rc == 0 {
            Some(key)
        } else {
            None
        }
    }
}

fn autostart_enabled() -> bool {
    let Some(key) = open_run_key() else { return false };
    let mut size = 0u32;
    let rc = unsafe {
        RegQueryValueExW(key, wide(RUN_VALUE).as_ptr(), null(), null_mut(), null_mut(), &mut size)
    };
    unsafe { RegCloseKey(key) };
    rc == 0
}

fn set_autostart(on: bool) {
    let Some(key) = open_run_key() else { return };
    unsafe {
        if on {
            if let Ok(exe) = std::env::current_exe() {
                let value = wide(&format!("\"{}\"", exe.display()));
                RegSetValueExW(
                    key,
                    wide(RUN_VALUE).as_ptr(),
                    0,
                    REG_SZ,
                    value.as_ptr() as *const u8,
                    (value.len() * 2) as u32,
                );
            }
        } else {
            RegDeleteValueW(key, wide(RUN_VALUE).as_ptr());
        }
        RegCloseKey(key);
    }
}

// ---------------------------------------------------------------------------
// QR code : une image qu'on ouvre avec le visualiseur de Windows.
// ---------------------------------------------------------------------------

fn show_qr(hwnd: HWND, url: &str) {
    let Some(bmp) = secure::qr_bmp(url) else {
        balloon(hwnd, "PandaPointer", "Impossible de fabriquer le QR code.");
        return;
    };
    let path = std::env::temp_dir().join(format!("PandaPointer-appairage-{}.bmp", std::process::id()));
    if std::fs::write(&path, bmp).is_err() {
        balloon(hwnd, "PandaPointer", "Impossible d'écrire le QR code.");
        return;
    }
    let file = wide(&path.display().to_string());
    unsafe {
        ShellExecuteW(hwnd, wide("open").as_ptr(), file.as_ptr(), null(), null(), SW_SHOWNORMAL);
    }
    CTX.with(|c| {
        if let Some(ctx) = c.borrow_mut().as_mut() {
            ctx.last_qr = Some(path);
        }
    });
}

/// Le QR code contient la clé secrète : on ne le laisse pas traîner dans le dossier temporaire.
fn remove_qr() {
    CTX.with(|c| {
        if let Some(ctx) = c.borrow().as_ref() {
            if let Some(p) = &ctx.last_qr {
                let _ = std::fs::remove_file(p);
            }
        }
    });
}

// ---------------------------------------------------------------------------
// Le menu
// ---------------------------------------------------------------------------

fn status_line(status: &Shared) -> (String, Vec<(DeviceId, String)>) {
    let st = status.lock().unwrap();
    let line = match &st.phone {
        Some((name, seen)) if seen.elapsed() < ONLINE_WINDOW => format!("Connecté : {name}"),
        _ if st.devices.is_empty() => "Aucun téléphone appairé".to_string(),
        _ => "En attente du téléphone".to_string(),
    };
    (line, st.devices.clone())
}

unsafe fn show_menu(hwnd: HWND) {
    let (status, commands) = CTX.with(|c| {
        let b = c.borrow();
        let ctx = b.as_ref().unwrap();
        (ctx.status.clone(), ctx.commands.clone())
    });
    let (line, devices) = status_line(&status);

    let menu = CreatePopupMenu();
    AppendMenuW(menu, MF_STRING | MF_GRAYED, 0, wide(&line).as_ptr());
    AppendMenuW(menu, MF_SEPARATOR, 0, null());
    AppendMenuW(menu, MF_STRING, ID_PAIR, wide("Appairer un téléphone…").as_ptr());

    let sub = CreatePopupMenu();
    if devices.is_empty() {
        AppendMenuW(sub, MF_STRING | MF_GRAYED, 0, wide("(aucun)").as_ptr());
    }
    for (i, (_, name)) in devices.iter().enumerate() {
        AppendMenuW(sub, MF_STRING, ID_FORGET_BASE + i, wide(&format!("Oublier {name}")).as_ptr());
    }
    AppendMenuW(menu, MF_POPUP | MF_STRING, sub as usize, wide("Téléphones appairés").as_ptr());

    let checked = if autostart_enabled() { MF_CHECKED } else { 0 };
    AppendMenuW(menu, MF_STRING | checked, ID_AUTOSTART, wide("Lancer avec Windows").as_ptr());
    AppendMenuW(menu, MF_SEPARATOR, 0, null());
    AppendMenuW(menu, MF_STRING, ID_QUIT, wide("Quitter PandaPointer").as_ptr());

    let mut p = POINT { x: 0, y: 0 };
    GetCursorPos(&mut p);
    // Obligatoire pour que le menu se ferme quand on clique ailleurs.
    SetForegroundWindow(hwnd);
    let choice = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON, p.x, p.y, 0, hwnd, null()) as usize;
    PostMessageW(hwnd, WM_NULL, 0, 0);
    DestroyMenu(menu); // détruit aussi le sous-menu

    match choice {
        ID_PAIR => {
            let _ = commands.send(Command::Pair);
        }
        ID_AUTOSTART => set_autostart(!autostart_enabled()),
        ID_QUIT => PostQuitMessage(0),
        n if n >= ID_FORGET_BASE => {
            if let Some((id, name)) = devices.get(n - ID_FORGET_BASE) {
                let _ = commands.send(Command::Forget(*id));
                balloon(hwnd, "PandaPointer", &format!("{name} est oublié."));
            }
        }
        _ => {}
    }
}

/// Toutes les demi-secondes : le réseau a-t-il quelque chose à montrer ?
unsafe fn on_timer(hwnd: HWND) {
    let (url, notice) = CTX.with(|c| {
        let b = c.borrow();
        let ctx = b.as_ref().unwrap();
        let mut st = ctx.status.lock().unwrap();
        (st.pair_url.take(), st.notice.take())
    });
    if let Some(url) = url {
        show_qr(hwnd, &url);
    }
    if let Some(text) = notice {
        balloon(hwnd, "PandaPointer", &text);
    }
}

unsafe extern "system" fn wnd_proc(hwnd: HWND, msg: u32, wp: WPARAM, lp: LPARAM) -> LRESULT {
    match msg {
        WM_TRAY => {
            let event = lp as u32;
            if event == WM_RBUTTONUP || event == WM_LBUTTONUP {
                show_menu(hwnd);
            }
            0
        }
        WM_TIMER => {
            on_timer(hwnd);
            0
        }
        m if CTX.with(|c| c.borrow().as_ref().map(|x| x.taskbar_created == m).unwrap_or(false)) => {
            // L'explorateur Windows a redémarré : on remet l'icône.
            notify(hwnd, NIM_ADD, "PandaPointer", None);
            0
        }
        _ => DefWindowProcW(hwnd, msg, wp, lp),
    }
}

/// Affiche l'icône et ne rend la main que quand l'utilisateur choisit « Quitter ».
pub fn run(commands: Sender<Command>, status: Shared, first_run_hint: bool) {
    unsafe {
        let taskbar_created = RegisterWindowMessageW(wide("TaskbarCreated").as_ptr());
        CTX.with(|c| {
            *c.borrow_mut() = Some(Ctx { commands, status, taskbar_created, last_qr: None });
        });

        let class = wide("PandaPointerTray");
        let hinst = GetModuleHandleW(null());
        let mut wc: WNDCLASSEXW = std::mem::zeroed();
        wc.cbSize = std::mem::size_of::<WNDCLASSEXW>() as u32;
        wc.lpfnWndProc = Some(wnd_proc);
        wc.hInstance = hinst;
        wc.lpszClassName = class.as_ptr();
        RegisterClassExW(&wc);
        // Fenêtre invisible : elle ne sert qu'à recevoir les messages de l'icône.
        let hwnd = CreateWindowExW(0, class.as_ptr(), class.as_ptr(), 0, 0, 0, 0, 0, null_mut(), null_mut(), hinst, null());
        if hwnd.is_null() {
            return;
        }

        notify(hwnd, NIM_ADD, "PandaPointer", None);
        SetTimer(hwnd, TIMER_ID, 500, None);
        if first_run_hint {
            balloon(hwnd, "Bienvenue", "Clique sur l'icône du panda puis « Appairer un téléphone ».");
        }

        let mut msg: MSG = std::mem::zeroed();
        while GetMessageW(&mut msg, null_mut(), 0, 0) > 0 {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }

        remove_qr();
        notify(hwnd, NIM_DELETE, "", None);
    }
}

//! Le pointeur laser : un petit point rouge lumineux, dessiné par-dessus tout
//! le reste (PowerPoint plein écran compris), qui suit les mouvements du téléphone.
//!
//! Le vrai curseur ne bouge pas pendant ce temps : le laser a sa propre position.
//! Technique : une fenêtre transparente, toujours au premier plan, que les clics
//! traversent (on ne la sent pas, comme une vitre) et qui ne vole jamais le focus.
//! Le dessin et la fenêtre ne concernent que Windows ; le suivi de position, lui,
//! est du calcul pur, testé sur n'importe quel système.

#![cfg_attr(not(windows), allow(dead_code))]

/// Position du laser, bloquée à l'intérieur de l'écran (tous écrans confondus).
pub struct Tracker {
    pub x: i32,
    pub y: i32,
    /// (gauche, haut, droite, bas) : droite et bas exclus.
    bounds: (i32, i32, i32, i32),
}

impl Tracker {
    pub fn new(bounds: (i32, i32, i32, i32)) -> Self {
        Self { x: bounds.0, y: bounds.1, bounds }
    }

    pub fn set_bounds(&mut self, bounds: (i32, i32, i32, i32)) {
        self.bounds = bounds;
        self.set(self.x, self.y);
    }

    pub fn set(&mut self, x: i32, y: i32) {
        let (l, t, r, b) = self.bounds;
        self.x = x.clamp(l, r - 1);
        self.y = y.clamp(t, b - 1);
    }

    pub fn move_by(&mut self, dx: i32, dy: i32) {
        self.set(self.x + dx, self.y + dy);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn laser_stays_on_screen() {
        let mut t = Tracker::new((0, 0, 1920, 1080));
        t.set(100, 100);
        t.move_by(50, -30);
        assert_eq!((t.x, t.y), (150, 70));
        t.move_by(-500, -500);
        assert_eq!((t.x, t.y), (0, 0));
        t.move_by(5000, 5000);
        assert_eq!((t.x, t.y), (1919, 1079));
    }

    #[test]
    fn second_screen_on_the_left_has_negative_coordinates() {
        // Deux écrans côte à côte, celui de gauche étant le second : x peut être négatif.
        let mut t = Tracker::new((-1920, 0, 1920, 1080));
        t.set(-100, 500);
        t.move_by(-5000, 0);
        assert_eq!(t.x, -1920);
    }

    #[test]
    fn bounds_change_pulls_the_laser_back_in() {
        let mut t = Tracker::new((0, 0, 3840, 1080));
        t.set(3000, 500);
        t.set_bounds((0, 0, 1920, 1080)); // un écran a été débranché
        assert_eq!(t.x, 1919);
    }
}

#[cfg(windows)]
pub use overlay::Overlay;

#[cfg(windows)]
mod overlay {
    use super::Tracker;
    use std::ptr::{null, null_mut};
    use std::sync::mpsc::{self, Receiver, RecvTimeoutError, Sender};
    use std::time::Duration;
    use windows_sys::Win32::Foundation::{POINT, SIZE};
    use windows_sys::Win32::Graphics::Gdi::{
        CreateCompatibleDC, CreateDIBSection, DeleteDC, DeleteObject, GetDC, ReleaseDC,
        SelectObject, AC_SRC_ALPHA, AC_SRC_OVER, BITMAPINFO, BITMAPINFOHEADER, BI_RGB,
        BLENDFUNCTION, DIB_RGB_COLORS,
    };
    use windows_sys::Win32::System::LibraryLoader::GetModuleHandleW;
    use windows_sys::Win32::UI::WindowsAndMessaging::{
        CreateWindowExW, DefWindowProcW, DestroyWindow, DispatchMessageW, GetCursorPos,
        GetSystemMetrics, PeekMessageW, RegisterClassExW, SetProcessDPIAware, SetWindowPos,
        ShowWindow, TranslateMessage, UpdateLayeredWindow, HWND_TOPMOST, MSG, PM_REMOVE,
        SM_CXVIRTUALSCREEN, SM_CYVIRTUALSCREEN, SM_XVIRTUALSCREEN, SM_YVIRTUALSCREEN,
        SWP_NOACTIVATE, SWP_NOSIZE, SWP_SHOWWINDOW, SW_HIDE, ULW_ALPHA, WNDCLASSEXW,
        WS_EX_LAYERED, WS_EX_NOACTIVATE, WS_EX_TOOLWINDOW, WS_EX_TOPMOST, WS_EX_TRANSPARENT,
        WS_POPUP,
    };

    /// Taille de la fenêtre (le point lumineux est dessiné en son centre).
    const DOT_SIZE: i32 = 44;

    #[derive(Clone, Copy)]
    struct State {
        visible: bool,
        x: i32,
        y: i32,
    }

    /// Le laser vu depuis le reste du programme : `show`, `move_by`, `hide`.
    /// La fenêtre vit dans son propre fil d'exécution (thread) : Windows exige que
    /// la fenêtre soit manipulée par le fil qui l'a créée.
    pub struct Overlay {
        tx: Sender<State>,
        tracker: Tracker,
        visible: bool,
    }

    impl Overlay {
        pub fn new() -> Self {
            let (tx, rx) = mpsc::channel();
            std::thread::spawn(move || overlay_thread(rx));
            Self { tx, tracker: Tracker::new(virtual_screen()), visible: false }
        }

        /// Allume le laser à l'endroit où se trouve le curseur.
        pub fn show(&mut self) {
            self.tracker.set_bounds(virtual_screen());
            let mut p = POINT { x: 0, y: 0 };
            unsafe { GetCursorPos(&mut p) };
            self.tracker.set(p.x, p.y);
            self.visible = true;
            self.push();
        }

        pub fn hide(&mut self) {
            self.visible = false;
            self.push();
        }

        pub fn move_by(&mut self, dx: i32, dy: i32) {
            if !self.visible {
                return;
            }
            self.tracker.move_by(dx, dy);
            self.push();
        }

        fn push(&self) {
            let _ = self.tx.send(State {
                visible: self.visible,
                x: self.tracker.x,
                y: self.tracker.y,
            });
        }
    }

    /// (gauche, haut, droite, bas) du bureau complet, tous écrans confondus.
    fn virtual_screen() -> (i32, i32, i32, i32) {
        unsafe {
            let l = GetSystemMetrics(SM_XVIRTUALSCREEN);
            let t = GetSystemMetrics(SM_YVIRTUALSCREEN);
            let w = GetSystemMetrics(SM_CXVIRTUALSCREEN);
            let h = GetSystemMetrics(SM_CYVIRTUALSCREEN);
            if w <= 0 || h <= 0 {
                return (0, 0, 1920, 1080);
            }
            (l, t, l + w, t + h)
        }
    }

    /// Dessine le point : un cœur rouge vif avec un halo qui s'estompe.
    /// Format attendu par Windows : B, G, R, A, avec les couleurs déjà multipliées par A.
    fn render_dot() -> Vec<u8> {
        let size = DOT_SIZE as usize;
        let c = (DOT_SIZE as f32 - 1.0) / 2.0;
        let mut px = vec![0u8; size * size * 4];
        for y in 0..size {
            for x in 0..size {
                let r = ((x as f32 - c).powi(2) + (y as f32 - c).powi(2)).sqrt();
                let (red, green, blue, alpha) = if r <= 2.5 {
                    (255.0, 200.0, 200.0, 255.0) // petit éclat blanc au centre
                } else if r <= 8.0 {
                    (255.0, 30.0, 30.0, 255.0) // cœur rouge
                } else if r <= c {
                    let k = 1.0 - (r - 8.0) / (c - 8.0); // halo qui s'estompe
                    (255.0, 30.0, 30.0, 255.0 * k * k * 0.8)
                } else {
                    (0.0, 0.0, 0.0, 0.0)
                };
                let a = alpha / 255.0;
                let i = (y * size + x) * 4;
                px[i] = (blue * a) as u8;
                px[i + 1] = (green * a) as u8;
                px[i + 2] = (red * a) as u8;
                px[i + 3] = alpha as u8;
            }
        }
        px
    }

    fn overlay_thread(rx: Receiver<State>) {
        unsafe {
            SetProcessDPIAware(); // mêmes pixels réels que la souris, même sur écran mis à l'échelle
            let hwnd = match create_window() {
                Some(h) => h,
                None => {
                    eprintln!("Laser : impossible de créer la fenêtre (le laser sera invisible).");
                    while rx.recv().is_ok() {} // on vide les messages pour ne pas bloquer
                    return;
                }
            };
            draw_dot(hwnd);

            let mut shown = false;
            loop {
                let mut msg: MSG = std::mem::zeroed();
                while PeekMessageW(&mut msg, null_mut(), 0, 0, PM_REMOVE) != 0 {
                    TranslateMessage(&msg);
                    DispatchMessageW(&msg);
                }
                match rx.recv_timeout(Duration::from_millis(8)) {
                    Ok(mut state) => {
                        // Si plusieurs ordres se sont accumulés, seul le dernier compte.
                        while let Ok(newer) = rx.try_recv() {
                            state = newer;
                        }
                        if state.visible {
                            SetWindowPos(
                                hwnd,
                                HWND_TOPMOST,
                                state.x - DOT_SIZE / 2,
                                state.y - DOT_SIZE / 2,
                                0,
                                0,
                                SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW,
                            );
                            shown = true;
                        } else if shown {
                            ShowWindow(hwnd, SW_HIDE);
                            shown = false;
                        }
                    }
                    Err(RecvTimeoutError::Timeout) => {}
                    Err(RecvTimeoutError::Disconnected) => break,
                }
            }
            DestroyWindow(hwnd);
        }
    }

    unsafe fn create_window() -> Option<windows_sys::Win32::Foundation::HWND> {
        let class_name: Vec<u16> = "PandaPointerLaser\0".encode_utf16().collect();
        let instance = GetModuleHandleW(null());
        let class = WNDCLASSEXW {
            cbSize: std::mem::size_of::<WNDCLASSEXW>() as u32,
            style: 0,
            lpfnWndProc: Some(DefWindowProcW),
            cbClsExtra: 0,
            cbWndExtra: 0,
            hInstance: instance,
            hIcon: null_mut(),
            hCursor: null_mut(),
            hbrBackground: null_mut(),
            lpszMenuName: null(),
            lpszClassName: class_name.as_ptr(),
            hIconSm: null_mut(),
        };
        RegisterClassExW(&class);
        let hwnd = CreateWindowExW(
            // layered = transparence par pixel ; transparent = les clics passent à travers ;
            // noactivate = ne vole jamais le focus ; toolwindow = absente de la barre des tâches.
            WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
            class_name.as_ptr(),
            class_name.as_ptr(),
            WS_POPUP,
            0,
            0,
            DOT_SIZE,
            DOT_SIZE,
            null_mut(),
            null_mut(),
            instance,
            null(),
        );
        if hwnd.is_null() {
            None
        } else {
            Some(hwnd)
        }
    }

    /// Donne à la fenêtre son image (le point) : fait une seule fois, ensuite on la déplace.
    unsafe fn draw_dot(hwnd: windows_sys::Win32::Foundation::HWND) {
        let screen = GetDC(null_mut());
        let memory = CreateCompatibleDC(screen);

        let mut info: BITMAPINFO = std::mem::zeroed();
        info.bmiHeader = BITMAPINFOHEADER {
            biSize: std::mem::size_of::<BITMAPINFOHEADER>() as u32,
            biWidth: DOT_SIZE,
            biHeight: -DOT_SIZE, // négatif = ligne du haut en premier
            biPlanes: 1,
            biBitCount: 32,
            biCompression: BI_RGB,
            biSizeImage: 0,
            biXPelsPerMeter: 0,
            biYPelsPerMeter: 0,
            biClrUsed: 0,
            biClrImportant: 0,
        };
        let mut bits: *mut core::ffi::c_void = null_mut();
        let bitmap = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &mut bits, null_mut(), 0);
        if !bitmap.is_null() && !bits.is_null() {
            let pixels = render_dot();
            std::ptr::copy_nonoverlapping(pixels.as_ptr(), bits as *mut u8, pixels.len());
            let old = SelectObject(memory, bitmap);

            let size = SIZE { cx: DOT_SIZE, cy: DOT_SIZE };
            let source = POINT { x: 0, y: 0 };
            let blend = BLENDFUNCTION {
                BlendOp: AC_SRC_OVER as u8,
                BlendFlags: 0,
                SourceConstantAlpha: 255,
                AlphaFormat: AC_SRC_ALPHA as u8,
            };
            UpdateLayeredWindow(hwnd, screen, null(), &size, memory, &source, 0, &blend, ULW_ALPHA);

            SelectObject(memory, old);
            DeleteObject(bitmap);
        }
        DeleteDC(memory);
        ReleaseDC(null_mut(), screen);
    }
}

//! Tout ce qui touche à la vraie souris et au clavier du PC est isolé ici.
//! Le reste du programme ne sait pas si la souris est réelle ou simulée.

use crate::protocol::{Button, GestureAction, SlideAction};

pub trait Cursor {
    fn move_by(&mut self, dx: i32, dy: i32);
    fn button(&mut self, button: Button, pressed: bool);
    fn click(&mut self, button: Button);
    /// Crans de molette : `dx` positif = vers la droite, `dy` positif = vers le bas.
    fn scroll(&mut self, dx: i32, dy: i32);
    fn slide(&mut self, action: SlideAction);
    fn gesture(&mut self, action: GestureAction);
    /// Zoom (Ctrl + molette) : positif = zoom avant.
    fn zoom(&mut self, steps: i32);
    /// Allume / éteint le laser (point rouge). Allumé, `laser_move_by` le déplace.
    fn laser(&mut self, on: bool);
    fn laser_move_by(&mut self, dx: i32, dy: i32);
}

/// Mode test : n'agit sur rien, affiche juste ce qu'il ferait.
/// Utile pour vérifier que le téléphone parle bien au PC sans que la souris s'affole.
pub struct DryRun;

impl Cursor for DryRun {
    fn move_by(&mut self, dx: i32, dy: i32) {
        println!("[test] déplacer de ({dx}, {dy})");
    }
    fn button(&mut self, button: Button, pressed: bool) {
        let etat = if pressed { "enfoncé" } else { "relâché" };
        println!("[test] bouton {button:?} {etat}");
    }
    fn click(&mut self, button: Button) {
        println!("[test] clic {button:?}");
    }
    fn scroll(&mut self, dx: i32, dy: i32) {
        println!("[test] défiler de ({dx}, {dy}) crans");
    }
    fn slide(&mut self, action: SlideAction) {
        println!("[test] diaporama : {action:?}");
    }
    fn gesture(&mut self, action: GestureAction) {
        println!("[test] geste : {action:?}");
    }
    fn zoom(&mut self, steps: i32) {
        println!("[test] zoom de {steps} crans");
    }
    fn laser(&mut self, on: bool) {
        println!("[test] laser {}", if on { "allumé" } else { "éteint" });
    }
    fn laser_move_by(&mut self, dx: i32, dy: i32) {
        println!("[test] laser déplacé de ({dx}, {dy})");
    }
}

#[cfg(any(target_os = "windows", target_os = "macos"))]
pub use real::RealCursor;

#[cfg(any(target_os = "windows", target_os = "macos"))]
mod real {
    use super::Cursor;
    use crate::protocol::{Button, GestureAction, SlideAction};
    use enigo::{
        Axis, Button as EnigoButton, Coordinate, Direction, Enigo, Key, Keyboard, Mouse, Settings,
    };

    pub struct RealCursor {
        enigo: Enigo,
        /// Créé à la première utilisation du laser (inutile de lancer un fil pour rien).
        #[cfg(windows)]
        laser: Option<crate::laser::Overlay>,
    }

    impl RealCursor {
        pub fn new() -> Result<Self, String> {
            let enigo = Enigo::new(&Settings::default()).map_err(|e| e.to_string())?;
            Ok(Self {
                enigo,
                #[cfg(windows)]
                laser: None,
            })
        }
    }

    impl RealCursor {
        /// Appuie sur des modificateurs (Alt, Win...), tape la touche, puis relâche tout.
        fn chord(&mut self, mods: &[Key], key: Key) {
            for m in mods {
                let _ = self.enigo.key(*m, Direction::Press);
            }
            if let Err(e) = self.enigo.key(key, Direction::Click) {
                eprintln!("Impossible d'envoyer le raccourci : {e}");
            }
            for m in mods.iter().rev() {
                let _ = self.enigo.key(*m, Direction::Release);
            }
        }
    }

    fn to_enigo(button: Button) -> EnigoButton {
        match button {
            Button::Left => EnigoButton::Left,
            Button::Right => EnigoButton::Right,
        }
    }

    impl Cursor for RealCursor {
        fn move_by(&mut self, dx: i32, dy: i32) {
            if let Err(e) = self.enigo.move_mouse(dx, dy, Coordinate::Rel) {
                eprintln!("Impossible de déplacer la souris : {e}");
            }
        }

        fn button(&mut self, button: Button, pressed: bool) {
            let d = if pressed { Direction::Press } else { Direction::Release };
            if let Err(e) = self.enigo.button(to_enigo(button), d) {
                eprintln!("Impossible d'utiliser le bouton : {e}");
            }
        }

        fn click(&mut self, button: Button) {
            if let Err(e) = self.enigo.button(to_enigo(button), Direction::Click) {
                eprintln!("Impossible de cliquer : {e}");
            }
        }

        fn scroll(&mut self, dx: i32, dy: i32) {
            if dy != 0 {
                if let Err(e) = self.enigo.scroll(dy, Axis::Vertical) {
                    eprintln!("Impossible de faire défiler : {e}");
                }
            }
            if dx != 0 {
                if let Err(e) = self.enigo.scroll(dx, Axis::Horizontal) {
                    eprintln!("Impossible de faire défiler : {e}");
                }
            }
        }

        fn zoom(&mut self, steps: i32) {
            // Zoom = Ctrl maintenu + molette. Molette vers le haut (valeur négative) = zoom avant.
            let _ = self.enigo.key(Key::Control, Direction::Press);
            if let Err(e) = self.enigo.scroll(-steps, Axis::Vertical) {
                eprintln!("Impossible de zoomer : {e}");
            }
            let _ = self.enigo.key(Key::Control, Direction::Release);
        }

        #[cfg(windows)]
        fn laser(&mut self, on: bool) {
            if on {
                self.laser.get_or_insert_with(crate::laser::Overlay::new).show();
            } else if let Some(l) = self.laser.as_mut() {
                l.hide();
            }
        }

        #[cfg(windows)]
        fn laser_move_by(&mut self, dx: i32, dy: i32) {
            if let Some(l) = self.laser.as_mut() {
                l.move_by(dx, dy);
            }
        }

        // Pas de laser dessiné sur Mac pour l'instant : le mouvement bouge le curseur à la place.
        #[cfg(not(windows))]
        fn laser(&mut self, _on: bool) {}

        #[cfg(not(windows))]
        fn laser_move_by(&mut self, dx: i32, dy: i32) {
            self.move_by(dx, dy);
        }

        fn gesture(&mut self, action: GestureAction) {
            let d = 'd';
            let (mods, key): (&[Key], Key) = match action {
                GestureAction::TaskView => (&[Key::Meta], Key::Tab),
                GestureAction::ShowDesktop => (&[Key::Meta], Key::Unicode(d)),
                GestureAction::NextApp => (&[Key::Alt], Key::Tab),
                GestureAction::PreviousApp => (&[Key::Alt, Key::Shift], Key::Tab),
                GestureAction::Search => (&[Key::Meta], Key::Unicode('s')),
                GestureAction::Notifications => (&[Key::Meta], Key::Unicode('a')),
                GestureAction::DesktopLeft => (&[Key::Control, Key::Meta], Key::LeftArrow),
                GestureAction::DesktopRight => (&[Key::Control, Key::Meta], Key::RightArrow),
            };
            self.chord(mods, key);
        }

        fn slide(&mut self, action: SlideAction) {
            let key = match action {
                SlideAction::Next => Key::RightArrow,
                SlideAction::Previous => Key::LeftArrow,
                SlideAction::Start => Key::F5,
                SlideAction::Stop => Key::Escape,
            };
            if let Err(e) = self.enigo.key(key, Direction::Click) {
                eprintln!("Impossible d'envoyer la touche : {e}");
            }
        }
    }
}

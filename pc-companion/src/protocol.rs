//! Le "langage" parlé entre le téléphone et le PC.
//!
//! Imagine un serveur qui reçoit des tickets de commande : chaque ticket est
//! très court et a toujours la même forme, pour être lu à toute vitesse.
//! Tous les tickets commencent pareil : [0] = type, [1..3] = numéro du ticket (u16).
//!
//!   type 1  MOUVEMENT (7 octets)  [3..5] dx (i16, pixels)   [5..7] dy (i16, pixels)
//!   type 2  BOUTON    (5 octets)  [3] bouton : 1 = gauche, 2 = droit
//!                                 [4] action : 0 = relâcher, 1 = enfoncer, 2 = clic complet
//!   type 3  SCROLL    (7 octets)  [3..5] horizontal (i16, crans) : positif = vers la droite
//!                                 [5..7] vertical   (i16, crans) : positif = vers le bas
//!   type 4  DIAPORAMA (4 octets)  [3] action : 1 = suivant, 2 = précédent,
//!                                              3 = démarrer (F5), 4 = quitter (Échap)
//!   type 5  GESTE     (4 octets)  [3] action : 1 = vue des tâches, 2 = bureau, 3 = appli suivante,
//!                                              4 = appli précédente, 5 = recherche,
//!                                              6 = notifications, 7 = bureau virtuel à gauche,
//!                                              8 = bureau virtuel à droite
//!   type 6  ZOOM      (5 octets)  [3..5] crans de zoom (i16) : positif = zoom avant
//!   type 7  LASER     (4 octets)  [3] 1 = allumer le laser, 0 = l'éteindre. Tant qu'il est allumé,
//!                                 les MOUVEMENTS déplacent le point laser et non le curseur.
//!
//! Tous les nombres sont en "little endian" (octet de poids faible d'abord).
//! Les mêmes octets sont décrits côté téléphone dans `mobile/lib/link.dart` :
//! les deux fichiers doivent toujours rester d'accord.

pub const DEFAULT_PORT: u16 = 4210;

/// Garde-fou : un seul ticket ne peut jamais déplacer le curseur de plus que ça.
pub const MAX_STEP: i16 = 200;

/// Garde-fou : un seul ticket ne peut jamais faire défiler de plus que ça (en crans).
pub const MAX_SCROLL: i16 = 20;

const TYPE_MOVE: u8 = 1;
const TYPE_BUTTON: u8 = 2;
const TYPE_SCROLL: u8 = 3;
const TYPE_SLIDE: u8 = 4;
const TYPE_GESTURE: u8 = 5;
const TYPE_ZOOM: u8 = 6;
const TYPE_LASER: u8 = 7;

/// Garde-fou : un seul ticket ne peut jamais zoomer de plus que ça (en crans).
pub const MAX_ZOOM: i16 = 10;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Button {
    Left,
    Right,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SlideAction {
    Next,
    Previous,
    Start,
    Stop,
}

/// Gestes "système" du touchpad (3 et 4 doigts) : chacun correspond à un raccourci Windows.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GestureAction {
    TaskView,
    ShowDesktop,
    NextApp,
    PreviousApp,
    Search,
    Notifications,
    DesktopLeft,
    DesktopRight,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Event {
    Move { dx: i16, dy: i16 },
    /// Bouton enfoncé (`pressed = true`) ou relâché (`false`), pour les glisser-déposer.
    Button { button: Button, pressed: bool },
    /// Clic complet (enfoncer puis relâcher) en un seul ticket : plus fiable
    /// qu'un enfoncé + un relâché, dont l'un des deux pourrait se perdre en route.
    Click { button: Button },
    Scroll { dx: i16, dy: i16 },
    Slide(SlideAction),
    Gesture(GestureAction),
    Zoom { steps: i16 },
    Laser { on: bool },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Packet {
    pub seq: u16,
    pub event: Event,
}

/// Lit un ticket. Renvoie `None` si le ticket est incompréhensible
/// (mauvaise taille, type inconnu...) : on l'ignore, on ne plante jamais.
pub fn parse(buf: &[u8]) -> Option<Packet> {
    let kind = *buf.first()?;
    let seq = u16::from_le_bytes([*buf.get(1)?, *buf.get(2)?]);
    match kind {
        TYPE_MOVE if buf.len() == 7 => {
            let dx = i16::from_le_bytes([buf[3], buf[4]]);
            let dy = i16::from_le_bytes([buf[5], buf[6]]);
            Some(Packet { seq, event: Event::Move { dx, dy } })
        }
        TYPE_BUTTON if buf.len() == 5 => {
            let button = match buf[3] {
                1 => Button::Left,
                2 => Button::Right,
                _ => return None,
            };
            let event = match buf[4] {
                0 => Event::Button { button, pressed: false },
                1 => Event::Button { button, pressed: true },
                2 => Event::Click { button },
                _ => return None,
            };
            Some(Packet { seq, event })
        }
        TYPE_SCROLL if buf.len() == 7 => {
            let dx = i16::from_le_bytes([buf[3], buf[4]]);
            let dy = i16::from_le_bytes([buf[5], buf[6]]);
            Some(Packet { seq, event: Event::Scroll { dx, dy } })
        }
        TYPE_GESTURE if buf.len() == 4 => {
            let action = match buf[3] {
                1 => GestureAction::TaskView,
                2 => GestureAction::ShowDesktop,
                3 => GestureAction::NextApp,
                4 => GestureAction::PreviousApp,
                5 => GestureAction::Search,
                6 => GestureAction::Notifications,
                7 => GestureAction::DesktopLeft,
                8 => GestureAction::DesktopRight,
                _ => return None,
            };
            Some(Packet { seq, event: Event::Gesture(action) })
        }
        TYPE_LASER if buf.len() == 4 => match buf[3] {
            0 => Some(Packet { seq, event: Event::Laser { on: false } }),
            1 => Some(Packet { seq, event: Event::Laser { on: true } }),
            _ => None,
        },
        TYPE_ZOOM if buf.len() == 5 => {
            let steps = i16::from_le_bytes([buf[3], buf[4]]);
            Some(Packet { seq, event: Event::Zoom { steps } })
        }
        TYPE_SLIDE if buf.len() == 4 => {
            let action = match buf[3] {
                1 => SlideAction::Next,
                2 => SlideAction::Previous,
                3 => SlideAction::Start,
                4 => SlideAction::Stop,
                _ => return None,
            };
            Some(Packet { seq, event: Event::Slide(action) })
        }
        _ => None,
    }
}

/// Le Wi-Fi peut livrer les tickets dans le désordre (c'est le principe de l'UDP).
/// Un ticket est accepté seulement s'il est plus récent que le dernier vu.
/// Le calcul fonctionne aussi quand le compteur repart à 0 après 65535.
pub fn is_newer(last: Option<u16>, seq: u16) -> bool {
    match last {
        None => true,
        Some(last) => (seq.wrapping_sub(last) as i16) > 0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Ces octets sont aussi vérifiés côté téléphone (mobile/test/link_test.dart) :
    /// si l'un des deux côtés change, l'un des deux tests casse.
    #[test]
    fn shared_vectors_with_phone() {
        let p = parse(&[1, 1, 0, 10, 0, 251, 255]).unwrap();
        assert_eq!(p, Packet { seq: 1, event: Event::Move { dx: 10, dy: -5 } });

        let p = parse(&[2, 2, 0, 1, 1]).unwrap();
        assert_eq!(p.event, Event::Button { button: Button::Left, pressed: true });

        let p = parse(&[2, 3, 0, 2, 2]).unwrap();
        assert_eq!(p.event, Event::Click { button: Button::Right });

        let p = parse(&[3, 4, 0, 2, 0, 253, 255]).unwrap();
        assert_eq!(p.event, Event::Scroll { dx: 2, dy: -3 });

        let p = parse(&[5, 6, 0, 7]).unwrap();
        assert_eq!(p.event, Event::Gesture(GestureAction::DesktopLeft));

        let p = parse(&[6, 7, 0, 253, 255]).unwrap();
        assert_eq!(p.event, Event::Zoom { steps: -3 });

        let p = parse(&[7, 8, 0, 1]).unwrap();
        assert_eq!(p.event, Event::Laser { on: true });
        let p = parse(&[7, 9, 0, 0]).unwrap();
        assert_eq!(p.event, Event::Laser { on: false });

        let p = parse(&[4, 5, 0, 1]).unwrap();
        assert_eq!(p.event, Event::Slide(SlideAction::Next));
    }

    #[test]
    fn parse_all_slide_actions() {
        assert_eq!(parse(&[4, 0, 0, 2]).unwrap().event, Event::Slide(SlideAction::Previous));
        assert_eq!(parse(&[4, 0, 0, 3]).unwrap().event, Event::Slide(SlideAction::Start));
        assert_eq!(parse(&[4, 0, 0, 4]).unwrap().event, Event::Slide(SlideAction::Stop));
    }

    #[test]
    fn parse_release() {
        let p = parse(&[TYPE_BUTTON, 1, 0, 1, 0]).unwrap();
        assert_eq!(p.event, Event::Button { button: Button::Left, pressed: false });
    }

    #[test]
    fn rejects_garbage() {
        assert!(parse(&[]).is_none());
        assert!(parse(&[9, 0, 0]).is_none());
        assert!(parse(&[TYPE_MOVE, 0, 0, 1]).is_none()); // trop court
        assert!(parse(&[TYPE_BUTTON, 0, 0, 3, 1]).is_none()); // bouton inconnu
        assert!(parse(&[TYPE_BUTTON, 0, 0, 1, 3]).is_none()); // action inconnue
        assert!(parse(&[TYPE_SCROLL, 0, 0, 1, 0]).is_none()); // trop court
        assert!(parse(&[TYPE_GESTURE, 0, 0, 9]).is_none()); // geste inconnu
        assert!(parse(&[TYPE_ZOOM, 0, 0, 1]).is_none()); // trop court
        assert!(parse(&[TYPE_LASER, 0, 0, 2]).is_none()); // état inconnu
        assert!(parse(&[TYPE_SLIDE, 0, 0, 9]).is_none()); // action inconnue
        assert!(parse(&[TYPE_SLIDE, 0, 0, 1, 1]).is_none()); // trop long
    }

    #[test]
    fn ordering() {
        assert!(is_newer(None, 0));
        assert!(is_newer(Some(5), 6));
        assert!(!is_newer(Some(5), 5)); // doublon
        assert!(!is_newer(Some(5), 4)); // en retard
        assert!(is_newer(Some(65535), 0)); // le compteur a fait le tour
    }
}

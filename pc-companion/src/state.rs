//! Ce que le réseau et le menu (icône de la barre des tâches) se disent entre eux.
//!
//! Image : le réseau est la cuisine, le menu est la salle. Ils ne se croisent pas : la salle
//! passe ses commandes sur un passe-plat (Command), la cuisine affiche l'état sur un tableau (Status).

use crate::secure::DeviceId;
use std::sync::{Arc, Mutex};
use std::time::Instant;

pub enum Command {
    /// Fabriquer un QR code d'appairage pour un nouveau téléphone.
    Pair,
    /// Oublier un téléphone appairé.
    Forget(DeviceId),
}

#[derive(Default)]
pub struct Status {
    /// Nom du dernier téléphone entendu et quand (pour afficher « connecté »).
    pub phone: Option<(String, Instant)>,
    /// Les téléphones appairés.
    pub devices: Vec<(DeviceId, String)>,
    /// Lien d'appairage à montrer en QR code (une seule fois : le menu le prend).
    pub pair_url: Option<String>,
    /// Message à afficher une fois (ex. « Téléphone 1 appairé »).
    pub notice: Option<String>,
}

pub type Shared = Arc<Mutex<Status>>;

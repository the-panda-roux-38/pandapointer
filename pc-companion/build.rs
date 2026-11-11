// Intègre l'icône du panda dans l'.exe (visible dans l'explorateur de fichiers).
// Si l'outil de ressources de Windows manque, on continue sans icône : rien ne casse.
fn main() {
    #[cfg(windows)]
    {
        let mut res = winresource::WindowsResource::new();
        res.set_icon("assets/pandapointer.ico");
        res.set("ProductName", "PandaPointer");
        res.set("FileDescription", "PandaPointer : ton téléphone devient une souris");
        if let Err(e) = res.compile() {
            println!("cargo:warning=icône de l'.exe non intégrée : {e}");
        }
    }
}

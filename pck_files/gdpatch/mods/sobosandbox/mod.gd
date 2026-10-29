extends Node

const LABEL_PATH = "Main/Ui/MainHBox/RightSidePanel/ScoringDisabled"

const TEXT = {
    "en": "  scoring and achievements\n  are disabled within\n  sandbox mode",
    "cs": "  skóre a úspěchy\n  jsou vypnuté v\n  sandboxovém režimu",
    "de": "  Punkte und Erfolge\n  sind im Sandbox-Modus\n  deaktiviert",
    "es": "  puntuación y logros\n  están desactivados en\n  el modo sandbox",
    "it": "  punteggi e obiettivi\n  sono disattivati nella\n  modalità sandbox",
    "ja": "  スコアと実績は\n  サンドボックスモードでは\n  無効になります",
    "pl": "  wyniki i osiągnięcia\n  są wyłączone w\n  trybie sandbox",
    "ru": "  очки и достижения\n  отключены в режиме\n  песочницы",
    "sr": "  rezultati i dostignuća\n  su isključeni u\n  sandbox modu",
    "zh_CN": "  在沙盒模式中\n  计分和成就已被禁用",
    "zh_TW": "  在沙盒模式中\n  計分和成就已被停用",
}

var lbl: Label

func _process(_d):
    if not is_instance_valid(lbl):
        lbl = get_tree().root.get_node_or_null(LABEL_PATH)
        if lbl == null:
            return
        lbl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
    var loc := TranslationServer.get_locale()
    var txt: String = TEXT.get(loc, TEXT.get(loc.substr(0, 2), TEXT["en"]))
    if lbl.text != txt:
        lbl.text = txt

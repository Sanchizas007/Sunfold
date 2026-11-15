"""Title, subtitle and keyword field per App Store locale, chosen from what people
actually type into each storefront (App Store search suggestions, 15.11.2026).

Kept as code, not JSON, so the reasoning stays next to the numbers.  The rules
this obeys: a word that is already in the title or subtitle is not repeated in
the keyword field (Apple indexes it once, the characters are wasted); keywords
are comma-separated with no spaces; and the field never names another app.
"""

SEO = {
    # US: the head terms (tracker, timer, 16:8) are owned by apps with 10k-450k
    # ratings, so the keyword field leans on the tails where the tenth result has
    # almost none: autophagy, water fasting, omad, widget, stages, clock.
    # "keto" replaces "ketosis" — people type the short word (73 suggestions vs 0).
    "en-US": ("Sunfold: Intermittent Fasting", "16:8 timer, widget & phases",
              "tracker,keto,omad,autophagy,water,clock,simple,stages,diet,weight,18:6,20:4,window,streak,history"),
    "en-GB": ("Sunfold: Intermittent Fasting", "16:8 timer, widget & phases",
              "tracker,keto,omad,autophagy,water,clock,simple,stages,diet,weight,18:6,20:4,window,streak,history"),
    "en-AU": ("Sunfold: Intermittent Fasting", "16:8 timer, widget & phases",
              "tracker,keto,omad,autophagy,water,clock,simple,stages,diet,weight,18:6,20:4,window,streak,history"),
    "en-CA": ("Sunfold: Intermittent Fasting", "16:8 timer, widget & phases",
              "tracker,keto,omad,autophagy,water,clock,simple,stages,diet,weight,18:6,20:4,window,streak,history"),
    # Non-English storefronts also get English queries ("intermittent fasting
    # widget" is among the first suggestions in DE, ES, PT, IT, KO, RU, ZH, NL, PL),
    # and Sunfold is invisible to them unless those words sit in the local field.
    "de-DE": ("Sunfold: Intervallfasten", "16:8 Fastentimer & Widget",
              "intermittent,fasting,tracker,diät,abnehmen,wasser,autophagie,keto,omad,phasen,18:6,20:4,gewicht,uhr"),
    "fr-FR": ("Sunfold : jeûne intermittent", "Minuteur 16:8, widget, phases",
              "fasting,tracker,timer,minuterie,traqueur,poids,régime,autophagie,eau,omad,18:6,20:4,suivi,keto"),
    "es-MX": ("Sunfold: ayuno intermitente", "Cronómetro 16:8 y fases",
              "intermittent,fasting,tracker,temporizador,contador,agua,peso,dieta,autofagia,widget,omad,18:6,20:4"),
    "es-ES": ("Sunfold: ayuno intermitente", "Temporizador 16:8 y widget",
              "intermittent,fasting,tracker,cronómetro,contador,agua,peso,dieta,autofagia,fases,omad,18:6,20:4"),
    "pt-BR": ("Sunfold: jejum intermitente", "Cronômetro 16:8 e widget",
              "intermittent,fasting,tracker,timer,monitor,dieta,peso,água,autofagia,fases,168,omad,18:6,20:4"),
    "it":    ("Sunfold: digiuno intermittente", "Timer 16:8, widget e fasi",
              "intermittent,fasting,tracker,dieta,piano,peso,acqua,autofagia,chetosi,omad,18:6,20:4,registro"),
    # Dutch use the English term; the local one is "intermitterend vasten".
    "nl-NL": ("Sunfold: intermitterend vasten", "16:8 timer, tracker & fasen",
              "intermittent,fasting,widget,dieet,gewicht,water,autofagie,keto,omad,18:6,20:4,periodiek,logboek,klok"),
    "pl":    ("Sunfold: post przerywany", "Minutnik 16:8, widżet i fazy",
              "intermittent,fasting,timer,tracker,dieta,woda,waga,autofagia,keto,omad,18:6,20:4,okno,widget"),
    "ru":    ("Sunfold: голодание 16:8", "Таймер, виджет и фазы",
              "интервальное,трекер,intermittent,fasting,диета,вода,аутофагия,кетоз,вес,окно,омад,18:6,20:4"),
    "uk":    ("Sunfold: голодування 16:8", "Таймер, віджет і фази",
              "інтервальне,трекер,intermittent,fasting,дієта,вода,аутофагія,кетоз,вага,вікно,омад,18:6,20:4"),
    # Japan: 断食タイマー and プチ断食 are the typed forms; 間欠的ファスティング is the formal name.
    "ja":    ("Sunfold: 間欠的ファスティング", "16時間断食タイマーとフェーズ",
              "断食,トラッカー,プチ断食,ダイエット,アプリ,間欠断食,オートファジー,体重,記録,ウィジェット,16時間,18:6,20:4,intermittent,fasting"),
    "ko":    ("Sunfold: 간헐적 단식", "16:8 단식 타이머와 대사 단계",
              "단식어플,추적기,다이어트,공복,간헐적단식,오토파지,체중,기록,위젯,18:6,20:4,intermittent,fasting,타이머"),
    "zh-Hans": ("Sunfold：间歇性断食", "16:8 断食计时器与代谢",
              "轻断食,断食,追踪,记录,减肥,生酮,自噬,体重,饮食,打卡,小组件,168,18:6,20:4,intermittent,fasting,进食窗口"),
    "zh-Hant": ("Sunfold：間歇性斷食", "16:8 斷食計時器與代謝",
              "輕斷食,斷食,追蹤,紀錄,減肥,生酮,自噬,體重,飲食,打卡,小工具,168,18:6,20:4,intermittent,fasting,進食時段"),
}

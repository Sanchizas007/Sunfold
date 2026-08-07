#!/usr/bin/env python3
"""Generates Shared/Resources/Localizable.xcstrings from the table below.

The catalog is machine-generated on purpose. Hand-editing a 250-key JSON file
across three languages is how strings drift apart; here every key is one row and
a missing translation is a build-time error rather than a silent fallback to
English.

Run after adding or changing any user-facing string:

    python3 Tools/build-strings.py

Then re-run `xcodebuild -exportLocalizations` and diff the key list against
`STRINGS` to catch keys that were added in code but never translated.
"""

import json
import os
import sys

# key: (en, uk, ru)
STRINGS = {
    # -- App / tabs -----------------------------------------------------------
    "app.name": ("Sunfold", "Sunfold", "Sunfold"),
    "tab.timer": ("Timer", "Таймер", "Таймер"),
    "tab.history": ("History", "Історія", "История"),
    "tab.weight": ("Weight", "Вага", "Вес"),
    "tab.settings": ("Settings", "Налаштування", "Настройки"),

    # -- Common ---------------------------------------------------------------
    "common.cancel": ("Cancel", "Скасувати", "Отмена"),
    "common.close": ("Close", "Закрити", "Закрыть"),
    "common.continue": ("Continue", "Далі", "Далее"),
    "common.delete": ("Delete", "Видалити", "Удалить"),
    "common.done": ("Done", "Готово", "Готово"),
    "common.edit": ("Edit", "Змінити", "Изменить"),
    "common.ok": ("OK", "Гаразд", "Хорошо"),
    "common.save": ("Save", "Зберегти", "Сохранить"),

    # -- Timer ----------------------------------------------------------------
    "timer.caption.elapsed": ("Fasting", "Голодування", "Голодание"),
    "timer.caption.eating": ("Eating window", "Вікно їжі", "Окно еды"),
    "timer.caption.ready": ("Ready", "Готово до старту", "Готово к старту"),
    "timer.subtitle.goal": ("of %@", "з %@", "из %@"),
    "timer.subtitle.windowLeft": ("left to eat", "лишилось на їжу", "осталось на еду"),
    "timer.start": ("Start fast", "Почати голодування", "Начать голодание"),
    "timer.end": ("End fast", "Завершити голодування", "Завершить голодание"),
    "timer.started": ("Started", "Початок", "Начало"),
    "timer.goal": ("Goal", "Ціль", "Цель"),
    "timer.window.until": ("Eat until", "Їсти до", "Есть до"),
    "timer.lastFast": ("Last fast", "Останнє голодування", "Последнее голодание"),
    "timer.completed": ("completed", "завершено", "завершено"),
    "timer.changeProtocol": ("change", "змінити", "изменить"),
    "timer.editStart": ("Edit start time", "Змінити час початку", "Изменить время начала"),
    "timer.editStart.note": (
        "Moved the start? Set the time you actually stopped eating. You can go back up to two days.",
        "Забули запустити вчасно? Вкажіть, коли ви справді припинили їсти. Можна відкотити до двох днів.",
        "Забыли запустить вовремя? Укажите, когда вы действительно перестали есть. Можно откатить до двух дней.",
    ),
    "timer.idle.title": ("No fast running", "Голодування не триває", "Голодание не идёт"),
    "timer.idle.body": (
        "Start whenever you finish your last meal. Sunfold counts from that moment and tells you when your goal is reached.",
        "Запускайте таймер після останнього прийому їжі. Sunfold рахує від цієї миті й повідомить, коли ціль досягнуто.",
        "Запускайте таймер после последнего приёма пищи. Sunfold считает с этого момента и сообщит, когда цель достигнута.",
    ),
    "timer.end.confirm.title": ("End this fast?", "Завершити голодування?", "Завершить голодание?"),
    "timer.end.confirm.message": (
        "It will be saved to your history with the time you have fasted so far.",
        "Його буде збережено в історії з тим часом, який ви вже проголодували.",
        "Оно сохранится в истории с тем временем, которое вы уже проголодали.",
    ),
    "timer.end.confirm.action": ("End fast", "Завершити", "Завершить"),
    "timer.longFast.title": ("A long fast", "Довге голодування", "Долгое голодание"),
    "timer.longFast.message": (
        "You are about to start a fast of 24 hours or more. Long fasts are not right for everyone — if you have any health condition or take medication, please speak to a doctor first.",
        "Ви збираєтесь почати голодування на 24 години або довше. Такі проміжки підходять не всім — якщо у вас є будь-які захворювання чи ви приймаєте ліки, спершу порадьтеся з лікарем.",
        "Вы собираетесь начать голодание на 24 часа или дольше. Такие промежутки подходят не всем — если у вас есть заболевания или вы принимаете лекарства, сначала посоветуйтесь с врачом.",
    ),
    "timer.longFast.start": ("Start anyway", "Все одно почати", "Всё равно начать"),
    "timer.longFast.notice": (
        "This is a long fast. Stop and eat if you feel dizzy, faint or unwell.",
        "Це довге голодування. Зупиніться та поїжте, якщо відчуєте запаморочення, слабкість чи нездужання.",
        "Это долгое голодание. Остановитесь и поешьте, если почувствуете головокружение, слабость или недомогание.",
    ),

    # -- Accessibility --------------------------------------------------------
    "a11y.fasting": (
        "Fasting in progress. Double tap to see the metabolic phases.",
        "Голодування триває. Двічі торкніться, щоб побачити фази метаболізму.",
        "Голодание идёт. Дважды коснитесь, чтобы увидеть фазы метаболизма.",
    ),
    "a11y.eating": (
        "Eating window. Time left before the next fast.",
        "Вікно їжі. Час до наступного голодування.",
        "Окно еды. Время до следующего голодания.",
    ),
    "a11y.idle": (
        "No fast running. Use the start button below.",
        "Голодування не триває. Скористайтеся кнопкою старту нижче.",
        "Голодание не идёт. Воспользуйтесь кнопкой старта ниже.",
    ),

    # -- Badges ---------------------------------------------------------------
    "badge.pro": ("Pro", "Pro", "Pro"),
    "badge.upgrade": ("Upgrade", "Оновити", "Улучшить"),
    "badge.daysLeft": ("%lld d", "%lld дн", "%lld дн"),

    # -- Protocols ------------------------------------------------------------
    "protocols.title": ("Fasting schedule", "Графік голодування", "График голодания"),
    "protocols.disclaimer": (
        "No schedule suits everyone. Pick the one that fits your day, and talk to a doctor if you are unsure.",
        "Жоден графік не підходить усім. Оберіть той, що вписується у ваш день, і порадьтеся з лікарем, якщо сумніваєтесь.",
        "Ни один график не подходит всем. Выберите тот, что вписывается в ваш день, и посоветуйтесь с врачом, если сомневаетесь.",
    ),
    "protocols.custom.length": ("Fast length", "Тривалість голодування", "Длительность голодания"),
    "protocols.custom.longNotice": (
        "Fasts of 24 hours or more are worth discussing with a doctor first.",
        "Голодування від 24 годин варто спершу обговорити з лікарем.",
        "Голодание от 24 часов стоит сначала обсудить с врачом.",
    ),
    "protocol.16_8.title": ("16:8", "16:8", "16:8"),
    "protocol.16_8.subtitle": (
        "16 h fasting · 8 h eating",
        "16 год голодування · 8 год їжі",
        "16 ч голодания · 8 ч еды",
    ),
    "protocol.16_8.blurb": (
        "The usual place to start — for most people that means a later breakfast or an earlier dinner.",
        "Найпоширеніший старт — зазвичай це пізніший сніданок або ранішня вечеря.",
        "Самый распространённый старт — обычно это поздний завтрак или ранний ужин.",
    ),
    "protocol.18_6.title": ("18:6", "18:6", "18:6"),
    "protocol.18_6.subtitle": (
        "18 h fasting · 6 h eating",
        "18 год голодування · 6 год їжі",
        "18 ч голодания · 6 ч еды",
    ),
    "protocol.18_6.blurb": (
        "A step up from 16:8, once that has become routine.",
        "Наступний крок після 16:8, коли той увійшов у звичку.",
        "Следующий шаг после 16:8, когда тот вошёл в привычку.",
    ),
    "protocol.20_4.title": ("20:4", "20:4", "20:4"),
    "protocol.20_4.subtitle": (
        "20 h fasting · 4 h eating",
        "20 год голодування · 4 год їжі",
        "20 ч голодания · 4 ч еды",
    ),
    "protocol.20_4.blurb": (
        "One long fast and a short window. Demanding — worth easing into.",
        "Довге голодування й коротке вікно. Вимогливий режим — заходьте поступово.",
        "Долгое голодание и короткое окно. Требовательный режим — заходите постепенно.",
    ),
    "protocol.5_2.title": ("5:2", "5:2", "5:2"),
    "protocol.5_2.subtitle": (
        "24 h fasting · twice a week",
        "24 год голодування · двічі на тиждень",
        "24 ч голодания · дважды в неделю",
    ),
    "protocol.5_2.blurb": (
        "Two longer fasts a week, eating normally on the other days.",
        "Два довші голодування на тиждень, решту днів — звичайне харчування.",
        "Два более долгих голодания в неделю, остальные дни — обычное питание.",
    ),
    "protocol.custom.title": ("Custom", "Свій", "Свой"),
    "protocol.custom.subtitle": (
        "Set your own length",
        "Встановіть свою тривалість",
        "Задайте свою длительность",
    ),
    "protocol.custom.blurb": (
        "Anything from 4 to 48 hours, in half-hour steps.",
        "Від 4 до 48 годин, з кроком у пів години.",
        "От 4 до 48 часов, с шагом в полчаса.",
    ),

    # -- Phases ---------------------------------------------------------------
    "phases.title": ("Metabolic phases", "Фази метаболізму", "Фазы метаболизма"),
    "phases.now": ("Now", "Зараз", "Сейчас"),
    "phases.range": ("%1$lld–%2$lld h", "%1$lld–%2$lld год", "%1$lld–%2$lld ч"),
    "phases.range.open": ("%lld h and beyond", "від %lld год", "от %lld ч"),
    "phases.disclaimer": (
        "These hours are approximations drawn from general research. What actually happens depends on your last meal, your activity and your body. This is educational information, not medical advice.",
        "Ці години — приблизні орієнтири із загальних досліджень. Що відбувається насправді, залежить від останнього прийому їжі, активності та вашого організму. Це освітня інформація, а не медична порада.",
        "Эти часы — приблизительные ориентиры из общих исследований. Что происходит на самом деле, зависит от последнего приёма пищи, активности и вашего организма. Это образовательная информация, а не медицинский совет.",
    ),
    "phase.fed.title": ("Fed state", "Ситий стан", "Сытое состояние"),
    "phase.fed.summary": (
        "Your body is digesting the last meal and running on it.",
        "Організм перетравлює останній прийом їжі й живиться ним.",
        "Организм переваривает последний приём пищи и живёт на нём.",
    ),
    "phase.fed.detail": (
        "Blood sugar and insulin typically rise after eating, and energy comes from the meal rather than from stores.",
        "Після їжі цукор у крові й інсулін зазвичай зростають, і енергія береться з їжі, а не із запасів.",
        "После еды сахар в крови и инсулин обычно растут, и энергия берётся из пищи, а не из запасов.",
    ),
    "phase.early.title": ("Early fasting", "Раннє голодування", "Раннее голодание"),
    "phase.early.summary": (
        "Insulin falls and the liver begins releasing stored glucose.",
        "Інсулін знижується, і печінка починає віддавати запаси глюкози.",
        "Инсулин снижается, и печень начинает отдавать запасы глюкозы.",
    ),
    "phase.early.detail": (
        "Glycogen — glucose stored in the liver and muscles — usually covers energy needs through this window.",
        "Глікоген — глюкоза, запасена в печінці та м'язах, — зазвичай покриває потребу в енергії протягом цього проміжку.",
        "Гликоген — глюкоза, запасённая в печени и мышцах, — обычно покрывает потребность в энергии в этом промежутке.",
    ),
    "phase.fat.title": ("Fat burning", "Спалювання жиру", "Сжигание жира"),
    "phase.fat.summary": (
        "Glycogen runs low and the body turns more towards fat for fuel.",
        "Глікогену стає менше, і організм дедалі більше переходить на жир як паливо.",
        "Гликогена становится меньше, и организм всё больше переходит на жир как топливо.",
    ),
    "phase.fat.detail": (
        "The shift is gradual rather than a switch, and how quickly it happens varies a great deal between people.",
        "Перехід поступовий, а не миттєвий, і його швидкість дуже різна в різних людей.",
        "Переход постепенный, а не мгновенный, и его скорость сильно различается у разных людей.",
    ),
    "phase.ketosis.title": ("Ketosis", "Кетоз", "Кетоз"),
    "phase.ketosis.summary": (
        "The liver produces ketones from fat, which the brain can use as fuel.",
        "Печінка виробляє кетони з жиру, і мозок може використовувати їх як паливо.",
        "Печень вырабатывает кетоны из жира, и мозг может использовать их как топливо.",
    ),
    "phase.ketosis.detail": (
        "Some people report steadier energy and less hunger here; others notice nothing in particular. Both are normal.",
        "Дехто відзначає рівнішу енергію та менший голод, дехто не помічає нічого особливого. Обидва варіанти нормальні.",
        "Кто-то отмечает более ровную энергию и меньший голод, кто-то не замечает ничего особенного. Оба варианта нормальны.",
    ),
    "phase.autophagy.title": ("Autophagy", "Аутофагія", "Аутофагия"),
    "phase.autophagy.summary": (
        "Cellular recycling is thought to increase during longer fasts.",
        "Вважається, що під час довших голодувань посилюється клітинне самооновлення.",
        "Считается, что во время долгих голоданий усиливается клеточное самообновление.",
    ),
    "phase.autophagy.detail": (
        "Most of what is known comes from animal studies. Human research is still limited, and there is no way to measure it from a phone.",
        "Більшість відомого походить із досліджень на тваринах. Досліджень на людях поки мало, а виміряти це з телефона неможливо.",
        "Большая часть известного получена в исследованиях на животных. Исследований на людях пока мало, а измерить это с телефона невозможно.",
    ),

    # -- History --------------------------------------------------------------
    "history.title": ("History", "Історія", "История"),
    "history.stat.streak": ("Streak", "Серія", "Серия"),
    "history.stat.totalFasts": ("Fasts", "Голодувань", "Голоданий"),
    "history.stat.average": ("Average", "Середнє", "Среднее"),
    "history.stat.totalHours": ("Total", "Усього", "Всего"),
    "history.sessions": ("All fasts", "Усі голодування", "Все голодания"),
    "history.running": ("running", "триває", "идёт"),
    "history.chart.title": ("Last 14 days", "Останні 14 днів", "Последние 14 дней"),
    "history.chart.day": ("Day", "День", "День"),
    "history.chart.hours": ("Hours", "Годин", "Часов"),
    "history.chart.locked.title": ("Charts are in Pro", "Графіки — у Pro", "Графики — в Pro"),
    "history.chart.locked.body": (
        "See how your fasting hours add up over time.",
        "Дивіться, як накопичуються ваші години голодування.",
        "Смотрите, как накапливаются ваши часы голодания.",
    ),
    "history.locked.title": ("Showing the last 7 days", "Показано останні 7 днів", "Показаны последние 7 дней"),
    "history.locked.body": (
        "Your older fasts are still saved. Unlock Pro to see all of them.",
        "Давніші голодування збережено. Відкрийте Pro, щоб побачити їх усі.",
        "Прошлые голодания сохранены. Откройте Pro, чтобы увидеть их все.",
    ),
    "history.empty.title": ("Nothing here yet", "Поки що порожньо", "Пока пусто"),
    "history.empty.body": (
        "Your finished fasts will appear here.",
        "Тут з'являться ваші завершені голодування.",
        "Здесь появятся ваши завершённые голодания.",
    ),
    "history.calendar.fasted": ("fasted", "було голодування", "было голодание"),
    "history.calendar.none": ("no fast", "без голодування", "без голодания"),
    "history.editor.title": ("Fast details", "Деталі голодування", "Детали голодания"),
    "history.editor.duration": ("Duration", "Тривалість", "Длительность"),
    "history.editor.feeling": ("How did it feel?", "Як воно відчувалося?", "Как это ощущалось?"),
    "history.editor.note": ("Note", "Нотатка", "Заметка"),
    "history.editor.notePlaceholder": (
        "Anything worth remembering",
        "Щось, що варто запам'ятати",
        "Что-то, что стоит запомнить",
    ),

    # -- Weight ---------------------------------------------------------------
    "weight.title": ("Weight", "Вага", "Вес"),
    "weight.add": ("Add weight", "Додати вагу", "Добавить вес"),
    "weight.current": ("Latest", "Останнє", "Последнее"),
    "weight.date": ("Date", "Дата", "Дата"),
    "weight.note": ("Note", "Нотатка", "Заметка"),
    "weight.notePlaceholder": ("Optional", "Необов'язково", "Необязательно"),
    "weight.entries": ("Entries", "Записи", "Записи"),
    "weight.chart.title": ("Trend", "Динаміка", "Динамика"),
    "weight.chart.date": ("Date", "Дата", "Дата"),
    "weight.chart.value": ("Weight", "Вага", "Вес"),
    "weight.chart.locked.title": ("The chart is in Pro", "Графік — у Pro", "График — в Pro"),
    "weight.chart.locked.body": (
        "Watch the trend instead of single numbers.",
        "Дивіться на динаміку, а не на окремі цифри.",
        "Смотрите на динамику, а не на отдельные цифры.",
    ),
    "weight.chart.empty.title": ("Two entries needed", "Потрібно два записи", "Нужно две записи"),
    "weight.chart.empty.body": (
        "Add one more weight to see the trend.",
        "Додайте ще одну вагу, щоб побачити динаміку.",
        "Добавьте ещё один вес, чтобы увидеть динамику.",
    ),
    "weight.empty.title": ("No weight recorded", "Вага ще не записана", "Вес ещё не записан"),
    "weight.empty.body": (
        "Weighing yourself is optional. Sunfold works perfectly well without it.",
        "Зважуватися необов'язково. Sunfold чудово працює й без цього.",
        "Взвешиваться необязательно. Sunfold прекрасно работает и без этого.",
    ),
    "unit.kilograms": ("Kilograms", "Кілограми", "Килограммы"),
    "unit.pounds": ("Pounds", "Фунти", "Фунты"),

    # Duration suffixes. Separate keys rather than a spliced-in letter: "16h"
    # is idiomatic English but wrong in Ukrainian and Russian, which also want
    # a space before the unit.
    "duration.hoursMinutes": ("%1$lldh %2$lldm", "%1$lld год %2$lld хв", "%1$lld ч %2$lld мин"),
    "duration.hours": ("%lldh", "%lld год", "%lld ч"),
    "duration.minutes": ("%lldm", "%lld хв", "%lld мин"),

    # -- Settings -------------------------------------------------------------
    "settings.title": ("Settings", "Налаштування", "Настройки"),
    "settings.section.fasting": ("Fasting", "Голодування", "Голодание"),
    "settings.section.notifications": ("Notifications", "Сповіщення", "Уведомления"),
    "settings.section.appearance": ("Appearance", "Вигляд", "Внешний вид"),
    "settings.section.data": ("Your data", "Ваші дані", "Ваши данные"),
    "settings.section.about": ("About", "Про застосунок", "О приложении"),
    "settings.protocol": ("Schedule", "Графік", "График"),
    "settings.notify.complete": ("Fast complete", "Голодування завершено", "Голодание завершено"),
    "settings.notify.before": ("30 minutes before", "За 30 хвилин до кінця", "За 30 минут до конца"),
    "settings.notify.window": ("Eating window ends", "Вікно їжі закривається", "Окно еды закрывается"),
    "settings.notify.denied": (
        "Notifications are off in iOS Settings",
        "Сповіщення вимкнено в налаштуваннях iOS",
        "Уведомления выключены в настройках iOS",
    ),
    "settings.liveActivity": ("Live Activity", "Live Activity", "Live Activity"),
    "settings.theme": ("Theme", "Тема", "Тема"),
    "settings.units": ("Weight units", "Одиниці ваги", "Единицы веса"),
    # Kept to one word: this is the value of a menu picker in a narrow row, and
    # a two-word label wrapped onto a second line.
    "appearance.system": ("System", "Системна", "Системная"),
    "appearance.light": ("Light", "Світла", "Светлая"),
    "appearance.dark": ("Dark", "Темна", "Тёмная"),
    "settings.export": ("Export as CSV", "Експорт у CSV", "Экспорт в CSV"),
    "settings.deleteAll": ("Delete all data", "Видалити всі дані", "Удалить все данные"),
    "settings.deleteAll.confirm.title": (
        "Delete everything?",
        "Видалити все?",
        "Удалить всё?",
    ),
    "settings.deleteAll.confirm.message": (
        "Every fast, weight entry and note will be removed from this device. This cannot be undone.",
        "Усі голодування, записи ваги та нотатки буде видалено з цього пристрою. Це не можна скасувати.",
        "Все голодания, записи веса и заметки будут удалены с этого устройства. Это нельзя отменить.",
    ),
    "settings.deleteAll.confirm.action": ("Delete everything", "Видалити все", "Удалить всё"),
    "settings.disclaimer": ("Health notice", "Застереження про здоров'я", "Предупреждение о здоровье"),
    "settings.privacy": ("Privacy Policy", "Політика приватності", "Политика конфиденциальности"),
    "settings.terms": ("Terms of Use", "Умови використання", "Условия использования"),
    "settings.support": ("Contact support", "Написати в підтримку", "Написать в поддержку"),
    "settings.version": ("Version", "Версія", "Версия"),
    "settings.footer": (
        "Sunfold keeps everything on your device. No account, no server, no tracking.",
        "Sunfold зберігає все на вашому пристрої. Без акаунта, без сервера, без стеження.",
        "Sunfold хранит всё на вашем устройстве. Без аккаунта, без сервера, без слежки.",
    ),
    "settings.pro.title": ("Sunfold Pro", "Sunfold Pro", "Sunfold Pro"),
    "settings.pro.active": ("Sunfold Pro is active", "Sunfold Pro активний", "Sunfold Pro активен"),
    "settings.pro.body": (
        "Every schedule, your full history, charts and widgets.",
        "Усі графіки, повна історія, діаграми та віджети.",
        "Все графики, полная история, диаграммы и виджеты.",
    ),
    "settings.pro.activeBody": (
        "Thank you. Everything is unlocked.",
        "Дякуємо. Усе відкрито.",
        "Спасибо. Всё открыто.",
    ),
    "settings.pro.trialBody": (
        "You have full access during your first week.",
        "Протягом першого тижня у вас повний доступ.",
        "В течение первой недели у вас полный доступ.",
    ),

    # -- Paywall --------------------------------------------------------------
    "paywall.title": ("Sunfold Pro", "Sunfold Pro", "Sunfold Pro"),
    "paywall.subtitle": (
        "Every schedule, your whole history, the charts and the metabolic phases.",
        "Усі графіки, вся ваша історія, діаграми та фази метаболізму.",
        "Все графики, вся ваша история, диаграммы и фазы метаболизма.",
    ),
    "paywall.subtitle.trial": (
        "You have full access during your first week. Keep it when the week ends.",
        "Протягом першого тижня у вас повний доступ. Залиште його, коли тиждень мине.",
        "В течение первой недели у вас полный доступ. Сохраните его, когда неделя закончится.",
    ),
    "paywall.benefit.protocols": ("Every schedule", "Усі графіки", "Все графики"),
    "paywall.benefit.protocols.body": (
        "18:6, 20:4, 5:2 and your own length from 4 to 48 hours.",
        "18:6, 20:4, 5:2 і власна тривалість від 4 до 48 годин.",
        "18:6, 20:4, 5:2 и своя длительность от 4 до 48 часов.",
    ),
    "paywall.benefit.history": ("Unlimited history", "Безлімітна історія", "Безлимитная история"),
    "paywall.benefit.history.body": (
        "Every fast you have ever recorded, not just the last week.",
        "Кожне записане голодування, а не лише останній тиждень.",
        "Каждое записанное голодание, а не только последняя неделя.",
    ),
    "paywall.benefit.charts": ("Charts", "Діаграми", "Диаграммы"),
    "paywall.benefit.charts.body": (
        "Fasting hours and weight trend over time.",
        "Години голодування та динаміка ваги в часі.",
        "Часы голодания и динамика веса во времени.",
    ),
    "paywall.benefit.phases": ("Metabolic phases", "Фази метаболізму", "Фазы метаболизма"),
    "paywall.benefit.phases.body": (
        "See which phase your fast is in, and what it means.",
        "Дивіться, у якій фазі ваше голодування і що це означає.",
        "Смотрите, в какой фазе ваше голодание и что это значит.",
    ),
    "paywall.benefit.widgets": ("Widgets", "Віджети", "Виджеты"),
    "paywall.benefit.widgets.body": (
        "The timer on your Home Screen, Lock Screen and Dynamic Island.",
        "Таймер на екрані «Домівка», екрані блокування та в Dynamic Island.",
        "Таймер на домашнем экране, экране блокировки и в Dynamic Island.",
    ),
    "paywall.plan.monthly": ("Monthly", "Щомісяця", "Ежемесячно"),
    "paywall.plan.monthly.detail": (
        "Billed every month",
        "Списується щомісяця",
        "Списывается ежемесячно",
    ),
    "paywall.plan.yearly": ("Yearly", "Щороку", "Ежегодно"),
    "paywall.plan.yearly.detail": ("Billed every year", "Списується щороку", "Списывается ежегодно"),
    "paywall.plan.yearly.detailPerMonth": (
        "Billed yearly · %@ / month",
        "Списується щороку · %@ / місяць",
        "Списывается ежегодно · %@ / месяц",
    ),
    "paywall.plan.lifetime": ("Lifetime", "Назавжди", "Навсегда"),
    "paywall.plan.lifetime.detail": (
        "One payment, no renewal",
        "Один платіж, без поновлення",
        "Один платёж, без продления",
    ),
    "paywall.save": ("Save %lld%%", "Вигода %lld%%", "Выгода %lld%%"),
    "paywall.cta.subscribe": ("Subscribe", "Оформити підписку", "Оформить подписку"),
    "paywall.cta.buy": ("Buy Sunfold Pro", "Купити Sunfold Pro", "Купить Sunfold Pro"),
    "paywall.restore": ("Restore", "Відновити", "Восстановить"),
    "paywall.manage": (
        "Manage subscription",
        "Керувати підпискою",
        "Управлять подпиской",
    ),
    "paywall.restore.nothing": (
        "No previous purchase was found on this Apple ID.",
        "На цьому Apple ID не знайдено попередніх покупок.",
        "На этом Apple ID не найдено прежних покупок.",
    ),
    "paywall.terms.subscription": (
        "Payment is charged to your Apple ID. The subscription renews automatically unless it is cancelled at least 24 hours before the period ends. Manage or cancel it any time in App Store settings.",
        "Оплата списується з вашого Apple ID. Підписка поновлюється автоматично, якщо її не скасувати щонайменше за 24 години до кінця періоду. Керувати чи скасувати можна будь-коли в налаштуваннях App Store.",
        "Оплата списывается с вашего Apple ID. Подписка продлевается автоматически, если её не отменить минимум за 24 часа до конца периода. Управлять или отменить можно в любой момент в настройках App Store.",
    ),
    "paywall.terms.lifetime": (
        "A single payment with no renewal. Sunfold Pro stays with your Apple ID.",
        "Один платіж без поновлення. Sunfold Pro залишається на вашому Apple ID.",
        "Один платёж без продления. Sunfold Pro остаётся на вашем Apple ID.",
    ),
    "paywall.error.title": ("Something went wrong", "Щось пішло не так", "Что-то пошло не так"),
    "paywall.error.unavailable": (
        "That plan is not available right now. Please try again later.",
        "Цей план зараз недоступний. Спробуйте пізніше.",
        "Этот план сейчас недоступен. Попробуйте позже.",
    ),
    "paywall.error.notConfigured": (
        "Purchases are not available in this build.",
        "Покупки недоступні в цій збірці.",
        "Покупки недоступны в этой сборке.",
    ),
    "paywall.notConfigured": (
        "Development build: the store is not connected, so nothing can be purchased here.",
        "Збірка для розробки: магазин не під'єднано, тут нічого не можна купити.",
        "Сборка для разработки: магазин не подключён, здесь ничего нельзя купить.",
    ),

    # -- Onboarding -----------------------------------------------------------
    "onboarding.welcome.title": ("Welcome to Sunfold", "Вітаємо в Sunfold", "Добро пожаловать в Sunfold"),
    "onboarding.welcome.body": (
        "A calm timer for intermittent fasting. No feed, no streak-shaming, no ads.",
        "Спокійний таймер для інтервального голодування. Без стрічки, без докорів за зірвану серію, без реклами.",
        "Спокойный таймер для интервального голодания. Без ленты, без упрёков за сорванную серию, без рекламы.",
    ),
    "onboarding.welcome.point1": (
        "One ring shows exactly where you are.",
        "Одне кільце показує, де ви саме зараз.",
        "Одно кольцо показывает, где вы сейчас.",
    ),
    "onboarding.welcome.point2": (
        "See which metabolic phase your fast has reached.",
        "Дивіться, якої фази метаболізму досягло голодування.",
        "Смотрите, какой фазы метаболизма достигло голодание.",
    ),
    "onboarding.welcome.point3": (
        "Everything stays on your phone. No account needed.",
        "Усе залишається на вашому телефоні. Акаунт не потрібен.",
        "Всё остаётся на вашем телефоне. Аккаунт не нужен.",
    ),
    "onboarding.health.title": ("Before you start", "Перш ніж почати", "Прежде чем начать"),
    "onboarding.health.body": (
        "Sunfold is a timer and a journal. It is not a medical device and it gives no medical advice.",
        "Sunfold — це таймер і щоденник. Це не медичний пристрій, і він не дає медичних порад.",
        "Sunfold — это таймер и дневник. Это не медицинское устройство, и оно не даёт медицинских советов.",
    ),
    "onboarding.health.list": (
        "Please talk to a doctor before fasting if you are pregnant or breastfeeding, under 18, living with diabetes or taking medication that affects blood sugar, taking any medicine that must be taken with food, underweight, or living with a chronic condition.\n\nIf you have or have had an eating disorder, fasting apps can make things harder. Please seek support first.",
        "Порадьтеся з лікарем перед голодуванням, якщо ви вагітні або годуєте груддю, вам менше 18 років, у вас діабет чи ви приймаєте ліки, що впливають на рівень цукру, приймаєте будь-які ліки, які потрібно пити з їжею, маєте недостатню вагу або хронічне захворювання.\n\nЯкщо у вас є або був розлад харчової поведінки, застосунки для голодування можуть погіршити стан. Спершу зверніться по допомогу.",
        "Посоветуйтесь с врачом перед голоданием, если вы беременны или кормите грудью, вам меньше 18 лет, у вас диабет или вы принимаете лекарства, влияющие на уровень сахара, принимаете любые лекарства, которые нужно пить с едой, имеете недостаточный вес или хроническое заболевание.\n\nЕсли у вас есть или было расстройство пищевого поведения, приложения для голодания могут ухудшить состояние. Сначала обратитесь за помощью.",
    ),
    "onboarding.health.readMore": ("Read the full notice", "Прочитати повне застереження", "Прочитать полное предупреждение"),
    "onboarding.health.acknowledge": (
        "I have read this and understand that Sunfold does not give medical advice.",
        "Я прочитав це й розумію, що Sunfold не дає медичних порад.",
        "Я прочитал это и понимаю, что Sunfold не даёт медицинских советов.",
    ),
    "onboarding.protocol.title": ("Pick a schedule", "Оберіть графік", "Выберите график"),
    "onboarding.protocol.body": (
        "Not sure? 16:8 is where most people start.",
        "Не впевнені? Більшість починає з 16:8.",
        "Не уверены? Большинство начинает с 16:8.",
    ),
    "onboarding.protocol.note": (
        "You can change this at any time, even mid-fast.",
        "Це можна змінити будь-коли, навіть посеред голодування.",
        "Это можно изменить в любой момент, даже посреди голодания.",
    ),
    "onboarding.ready.title": ("You are set", "Усе готово", "Всё готово"),
    "onboarding.ready.body": (
        "Your first week has everything unlocked, so you can see the whole app before deciding anything.",
        "Перший тиждень усе відкрито, щоб ви побачили застосунок цілком, перш ніж щось вирішувати.",
        "Первую неделю всё открыто, чтобы вы увидели приложение целиком, прежде чем что-то решать.",
    ),
    "onboarding.ready.point1": (
        "Every schedule and the full history for seven days.",
        "Усі графіки та повна історія протягом семи днів.",
        "Все графики и полная история в течение семи дней.",
    ),
    "onboarding.ready.point2": (
        "Reminders when your fast ends — you choose whether to allow them.",
        "Нагадування, коли голодування завершиться — дозволити їх вирішуєте ви.",
        "Напоминания, когда голодание завершится — разрешить их решаете вы.",
    ),
    "onboarding.ready.point3": (
        "Add the widget and watch the timer from your Lock Screen.",
        "Додайте віджет і стежте за таймером з екрана блокування.",
        "Добавьте виджет и следите за таймером с экрана блокировки.",
    ),
    "onboarding.start": ("Start using Sunfold", "Почати користуватися", "Начать пользоваться"),

    # -- Notifications --------------------------------------------------------
    "notification.complete.title": ("Fast complete", "Голодування завершено", "Голодание завершено"),
    "notification.complete.body": (
        "You reached your goal. Open Sunfold to end the fast whenever you are ready.",
        "Ви досягли цілі. Відкрийте Sunfold й завершіть голодування, коли будете готові.",
        "Вы достигли цели. Откройте Sunfold и завершите голодание, когда будете готовы.",
    ),
    "notification.endingSoon.title": ("30 minutes to go", "Лишилось 30 хвилин", "Осталось 30 минут"),
    "notification.endingSoon.body": (
        "Your fast reaches its goal in half an hour.",
        "Ваше голодування досягне цілі за пів години.",
        "Ваше голодание достигнет цели через полчаса.",
    ),
    "notification.windowEnd.title": ("Eating window closing", "Вікно їжі закривається", "Окно еды закрывается"),
    "notification.windowEnd.body": (
        "Time to start the next fast when you are ready.",
        "Час починати наступне голодування, коли будете готові.",
        "Время начинать следующее голодание, когда будете готовы.",
    ),

    # -- Widget ---------------------------------------------------------------
    "widget.title": ("Fasting timer", "Таймер голодування", "Таймер голодания"),
    "widget.description": (
        "Your current fast at a glance.",
        "Ваше поточне голодування з одного погляду.",
        "Ваше текущее голодание с одного взгляда.",
    ),
    "widget.idle.value": ("—", "—", "—"),
    "widget.tapToStart": ("Tap to start", "Торкніться, щоб почати", "Нажмите, чтобы начать"),
    "widget.window": ("eating window", "вікно їжі", "окно еды"),
    "widget.locked": (
        "Widgets are part of Sunfold Pro",
        "Віджети входять у Sunfold Pro",
        "Виджеты входят в Sunfold Pro",
    ),
    "activity.goalAt": ("Goal %@", "Ціль %@", "Цель %@"),

    # -- Privacy policy -------------------------------------------------------
    "privacy.title": ("Privacy", "Приватність", "Конфиденциальность"),
    "privacy.heading": (
        "Your data stays on your phone",
        "Ваші дані залишаються на телефоні",
        "Ваши данные остаются на телефоне",
    ),
    "privacy.lede": (
        "Sunfold has no account, no server and no analytics. Everything you record lives on your device.",
        "У Sunfold немає акаунта, сервера й аналітики. Усе, що ви записуєте, живе на вашому пристрої.",
        "У Sunfold нет аккаунта, сервера и аналитики. Всё, что вы записываете, живёт на вашем устройстве.",
    ),
    "privacy.stored.title": ("What Sunfold stores", "Що зберігає Sunfold", "Что хранит Sunfold"),
    "privacy.stored.body": (
        "Your fasts, weight entries, notes and settings are saved on this device. If you have iPhone backups switched on, they are included in your own backup, which only you can open.",
        "Ваші голодування, записи ваги, нотатки й налаштування зберігаються на цьому пристрої. Якщо у вас увімкнено резервні копії iPhone, вони потрапляють до вашої власної копії, яку можете відкрити лише ви.",
        "Ваши голодания, записи веса, заметки и настройки хранятся на этом устройстве. Если у вас включены резервные копии iPhone, они попадают в вашу собственную копию, которую можете открыть только вы.",
    ),
    "privacy.notCollected.title": (
        "What Sunfold does not collect",
        "Чого Sunfold не збирає",
        "Чего Sunfold не собирает",
    ),
    "privacy.notCollected.body": (
        "No account, no email address, no advertising identifiers, no analytics or tracking SDKs, no location. Nothing you record is sent anywhere, because Sunfold has no server to send it to.",
        "Ні акаунта, ні електронної пошти, ні рекламних ідентифікаторів, ні аналітики чи трекінгових SDK, ні геолокації. Нічого із записаного вами нікуди не надсилається, бо в Sunfold просто немає сервера.",
        "Ни аккаунта, ни электронной почты, ни рекламных идентификаторов, ни аналитики или трекинговых SDK, ни геолокации. Ничего из записанного вами никуда не отправляется, потому что у Sunfold просто нет сервера.",
    ),
    "privacy.purchases.title": ("Purchases", "Покупки", "Покупки"),
    "privacy.purchases.body": (
        "Purchases are processed by Apple. To check whether Sunfold Pro is active, the app uses RevenueCat, which receives a randomly generated app user ID and your App Store receipt. It never receives your name, your email, or anything you record in Sunfold.",
        "Покупки обробляє Apple. Щоб перевірити, чи активний Sunfold Pro, застосунок використовує RevenueCat, який отримує випадково згенерований ідентифікатор користувача та ваш чек App Store. Він ніколи не отримує ваше ім'я, пошту чи будь-що записане в Sunfold.",
        "Покупки обрабатывает Apple. Чтобы проверить, активен ли Sunfold Pro, приложение использует RevenueCat, который получает случайно сгенерированный идентификатор пользователя и ваш чек App Store. Он никогда не получает ваше имя, почту или что-либо записанное в Sunfold.",
    ),
    "privacy.notifications.title": ("Notifications", "Сповіщення", "Уведомления"),
    "privacy.notifications.body": (
        "All reminders are scheduled locally by your iPhone. Sunfold has no push server, and notification content never leaves your device.",
        "Усі нагадування планує локально ваш iPhone. У Sunfold немає push-сервера, і вміст сповіщень ніколи не залишає ваш пристрій.",
        "Все напоминания планирует локально ваш iPhone. У Sunfold нет push-сервера, и содержимое уведомлений никогда не покидает ваше устройство.",
    ),
    "privacy.health.title": ("Apple Health", "Apple Health", "Apple Health"),
    "privacy.health.body": (
        "Sunfold does not read from or write to Apple Health.",
        "Sunfold не читає та не записує дані в Apple Health.",
        "Sunfold не читает и не записывает данные в Apple Health.",
    ),
    "privacy.deletion.title": ("Deleting your data", "Видалення даних", "Удаление данных"),
    "privacy.deletion.body": (
        "Settings → Delete all data removes every fast, weight entry and note immediately. Deleting the app removes everything else.",
        "Налаштування → Видалити всі дані миттєво прибирає всі голодування, записи ваги й нотатки. Видалення застосунку прибирає решту.",
        "Настройки → Удалить все данные мгновенно убирает все голодания, записи веса и заметки. Удаление приложения убирает остальное.",
    ),
    "privacy.children.title": ("Children", "Діти", "Дети"),
    "privacy.children.body": (
        "Sunfold is not directed at children and is not intended for anyone under 18 without medical supervision.",
        "Sunfold не призначена для дітей і не рекомендована особам до 18 років без нагляду лікаря.",
        "Sunfold не предназначена для детей и не рекомендована лицам до 18 лет без наблюдения врача.",
    ),
    "privacy.changes.title": ("Changes", "Зміни", "Изменения"),
    "privacy.changes.body": (
        "If this policy changes, the updated version appears here and on sunfold.app.",
        "Якщо політика зміниться, оновлена версія з'явиться тут і на sunfold.app.",
        "Если политика изменится, обновлённая версия появится здесь и на sunfold.app.",
    ),
    "privacy.contact": ("Contact us", "Написати нам", "Написать нам"),
    "privacy.updated": ("Last updated: August 2026", "Оновлено: серпень 2026", "Обновлено: август 2026"),

    # -- Health disclaimer ----------------------------------------------------
    "disclaimer.title": ("Health notice", "Застереження", "Предупреждение"),
    "disclaimer.heading": (
        "Sunfold is a timer, not a doctor",
        "Sunfold — це таймер, а не лікар",
        "Sunfold — это таймер, а не врач",
    ),
    "disclaimer.lede": (
        "Sunfold tracks when you eat. It cannot know anything about your health, and it does not diagnose, treat or advise.",
        "Sunfold відстежує, коли ви їсте. Вона нічого не знає про ваше здоров'я й не діагностує, не лікує та не радить.",
        "Sunfold отслеживает, когда вы едите. Она ничего не знает о вашем здоровье и не диагностирует, не лечит и не советует.",
    ),
    "disclaimer.notMedical.title": ("Not medical advice", "Це не медична порада", "Это не медицинский совет"),
    "disclaimer.notMedical.body": (
        "Everything in Sunfold, including the metabolic phases, is general educational information. It is not a diagnosis, a treatment plan, or a recommendation for you personally.",
        "Усе в Sunfold, включно з фазами метаболізму, — загальна освітня інформація. Це не діагноз, не план лікування й не рекомендація особисто для вас.",
        "Всё в Sunfold, включая фазы метаболизма, — общая образовательная информация. Это не диагноз, не план лечения и не рекомендация лично для вас.",
    ),
    "disclaimer.askFirst.title": ("Talk to a doctor first", "Спершу порадьтеся з лікарем", "Сначала посоветуйтесь с врачом"),
    "disclaimer.askFirst.body": (
        "Please speak to a healthcare professional before fasting if you are pregnant or breastfeeding, under 18, living with diabetes or taking medication that affects blood sugar, taking any medicine that must be taken with food, underweight, or living with a chronic condition.",
        "Зверніться до лікаря перед голодуванням, якщо ви вагітні чи годуєте груддю, вам менше 18 років, у вас діабет або ви приймаєте ліки, що впливають на рівень цукру, приймаєте будь-які ліки, які треба пити з їжею, маєте недостатню вагу чи хронічне захворювання.",
        "Обратитесь к врачу перед голоданием, если вы беременны или кормите грудью, вам меньше 18 лет, у вас диабет или вы принимаете лекарства, влияющие на уровень сахара, принимаете любые лекарства, которые надо пить с едой, имеете недостаточный вес или хроническое заболевание.",
    ),
    "disclaimer.stop.title": ("Stop if you feel unwell", "Зупиніться, якщо погано", "Остановитесь, если плохо"),
    "disclaimer.stop.body": (
        "Dizziness, faintness, confusion, a racing heart or unusual weakness are reasons to eat and to seek medical help. No streak is worth it.",
        "Запаморочення, слабкість, сплутаність свідомості, прискорене серцебиття чи незвична млявість — привід поїсти та звернутися по медичну допомогу. Жодна серія цього не варта.",
        "Головокружение, слабость, спутанность сознания, учащённое сердцебиение или необычная вялость — повод поесть и обратиться за медицинской помощью. Никакая серия этого не стоит.",
    ),
    "disclaimer.eatingDisorders.title": ("If food is difficult", "Якщо з їжею складно", "Если с едой сложно"),
    "disclaimer.eatingDisorders.body": (
        "If you have or have had an eating disorder, or if tracking meals makes you anxious, a fasting app can make things worse. Please talk to a doctor or a support service where you live before using Sunfold.",
        "Якщо у вас є або був розлад харчової поведінки, або якщо відстеження їжі викликає тривогу, застосунок для голодування може погіршити стан. Спершу поговоріть із лікарем або службою підтримки у вашій країні.",
        "Если у вас есть или было расстройство пищевого поведения, или если отслеживание еды вызывает тревогу, приложение для голодания может ухудшить состояние. Сначала поговорите с врачом или службой поддержки в вашей стране.",
    ),
    "disclaimer.phases.title": ("About the phases", "Про фази", "О фазах"),
    "disclaimer.phases.body": (
        "The hours shown for each metabolic phase are approximations from general research. What actually happens depends on your last meal, your activity, your sleep and your body. Treat them as a rough map, not a measurement.",
        "Години для кожної фази метаболізму — приблизні орієнтири із загальних досліджень. Що відбувається насправді, залежить від останнього прийому їжі, активності, сну та вашого організму. Сприймайте це як приблизну карту, а не вимірювання.",
        "Часы для каждой фазы метаболизма — приблизительные ориентиры из общих исследований. Что происходит на самом деле, зависит от последнего приёма пищи, активности, сна и вашего организма. Воспринимайте это как приблизительную карту, а не измерение.",
    ),
}

# Keys whose value changes with a count. Ukrainian and Russian need four plural
# categories where English needs two.
PLURALS = {
    "history.stat.days": {
        "en": {"one": "%lld day", "other": "%lld days"},
        "uk": {"one": "%lld день", "few": "%lld дні", "many": "%lld днів", "other": "%lld дня"},
        "ru": {"one": "%lld день", "few": "%lld дня", "many": "%lld дней", "other": "%lld дня"},
    },
}

LANGUAGES = ("en", "uk", "ru")


def build() -> dict:
    strings: dict = {}

    for key, values in STRINGS.items():
        if len(values) != len(LANGUAGES):
            raise SystemExit(f"{key}: expected {len(LANGUAGES)} translations, got {len(values)}")
        strings[key] = {
            "extractionState": "manual",
            "localizations": {
                language: {"stringUnit": {"state": "translated", "value": value}}
                for language, value in zip(LANGUAGES, values)
            },
        }

    for key, per_language in PLURALS.items():
        strings[key] = {
            "extractionState": "manual",
            "localizations": {
                language: {
                    "variations": {
                        "plural": {
                            category: {"stringUnit": {"state": "translated", "value": value}}
                            for category, value in forms.items()
                        }
                    }
                }
                for language, forms in per_language.items()
            },
        }

    return {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "Shared", "Resources", "Localizable.xcstrings")
    catalog = build()
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(catalog, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"wrote {len(catalog['strings'])} keys to {out}")


if __name__ == "__main__":
    sys.exit(main())

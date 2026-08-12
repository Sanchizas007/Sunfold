# Sunfold

Трекер интервального голодания для iOS. Нативный SwiftUI, всё на устройстве,
без аккаунта и без сервера.

- **Bundle ID:** `app.sunfold` · виджет `app.sunfold.widgets`
- **App Group:** `group.app.sunfold`
- **Минимум:** iOS 17.0 · только iPhone · только портрет
- **Собрано на:** Xcode 26.6, Swift 6 (язык 6.0, `MainActor` по умолчанию)

## Как собрать

```bash
open Sunfold.xcodeproj
```

Схема `Sunfold` собирает приложение вместе с расширением виджета. Из терминала:

```bash
xcodebuild -project Sunfold.xcodeproj -scheme Sunfold -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Единственная внешняя зависимость — RevenueCat (SPM, зафиксирован на 5.83.1).

## Структура

```
Config/          Info.plist и entitlements обоих таргетов
Shared/          Код, который компилируется в ОБА таргета
  Design/        Палитра, типографика, кольцо прогресса, компоненты
  Models/        FastSession, WeightEntry, протоколы, фазы метаболизма
  Engine/        Настройки, статистика, снапшот для виджета, форматтеры
  Resources/     Localizable.xcstrings (en/uk/ru)
Sunfold/          Только приложение
  App/           Точка входа, RootView с табами
  Features/      Экраны: Timer, History, Weight, Settings, Paywall, Onboarding
  Services/      SwiftData, уведомления, Live Activity, покупки, экспорт
SunfoldWidgets/   Только расширение: виджеты + Live Activity
Tools/           build-strings.py — генератор строкового каталога
docs/            Чек-лист сабмита и ASO
```

Проект использует **file-system synchronized groups** (Xcode 16+): новые файлы
в этих папках попадают в сборку сами, `.xcodeproj` править не нужно.

`Shared/` подключён к обоим таргетам, поэтому виджет рисует тем же кольцом и той
же палитрой, что и приложение, без дублирования кода и без отдельного модуля.

## Ключевые решения

**Время считается от даты старта, а не тикающим счётчиком.** `FastSession`
хранит `startDate`; всё остальное — производные от текущих часов. Поэтому
сворачивание приложения, перезагрузка телефона или убийство процесса не сбивают
таймер.

**Виджет читает снапшот, а не базу.** Приложение пишет `FastingSnapshot` (JSON,
несколько сотен байт) в общий App Group. Виджет рендерится мгновенно и не
открывает SwiftData в процессе с жёстким лимитом памяти.

**Live Activity обновляется только при смене фазы.** На экране —
самотикающий `Text(timerInterval:)`, поэтому пуши не нужны вообще: за всё
голодание уходит несколько обновлений.

**Покупки за абстракцией.** `PurchaseProviding` с тремя реализациями, выбор в
`Entitlements.init`:

| Условие | Провайдер | Что происходит |
|---|---|---|
| Есть `RCPublicAPIKey` | `RevenueCatProvider` | Прод |
| Ключа нет, debug | `StoreKitProvider` | Покупки против `Config/Sunfold.storekit`, ничего не списывается |
| Ключа нет, release | `UnconfiguredPurchaseProvider` | Пейвол рисуется, но продать отказывается |

Последняя строка намеренная: покупка, которую RevenueCat не увидит, — это
покупка, которую потом нельзя ни восстановить, ни поддержать. Лучше не продать,
чем продать мимо учёта.

Прогнать покупки сегодня, без единого аккаунта: [docs/RUNBOOK.md](docs/RUNBOOK.md),
раздел A.

**Тесты.** 55 тестов на движок, прогон 0,1 секунды:

```bash
xcodebuild test -project Sunfold.xcodeproj -scheme Sunfold -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Тестовый таргет компилирует `Shared/` напрямую, без хост-приложения. Тесты по
стрикам пинуют свой UTC-календарь и своё «сейчас» — иначе они проходили бы в
Киеве и падали в Лос-Анджелесе.

**Строки генерируются.** `Shared/Resources/Localizable.xcstrings` собирается из
`Tools/build-strings.py`. После добавления новой строки в коде:

```bash
python3 Tools/build-strings.py
```

Сверить, что в коде нет непереведённых ключей:

```bash
xcodebuild -exportLocalizations -project Sunfold.xcodeproj -localizationPath /tmp/loc -exportLanguage en
```

и сравнить список ключей из `/tmp/loc/en.xcloc` с таблицей `STRINGS` в скрипте.

## Проверить на своём iPhone

Скачать файл и поставить нельзя — в iOS нет аналога APK. Два рабочих пути
(бесплатно из Xcode по кабелю, либо TestFlight после оплаты $99) с пошаговыми
инструкциями и подвохом про App Groups — в
[docs/TEST-ON-DEVICE.md](docs/TEST-ON-DEVICE.md).

## Сайт с политиками

App Store требует публичный URL политики приватности, и ревьюеры сверяют его с
текстом внутри приложения. Поэтому сайт **генерируется из той же таблицы строк**,
что и экраны приложения — разойтись они не могут:

```bash
SUNFOLD_ORIGIN=https://sanchizas007.github.io SUNFOLD_BASE=/Sunfold python3 Tools/build-site.py
```

Опубликовано на GitHub Pages: **https://sanchizas007.github.io/Sunfold/**.
Деплой автоматический — любой пуш, меняющий `site/`, публикует заново.
Когда появится домен, пересобрать без переменных окружения.

Кладёт в `site/` пятнадцать страниц (лендинг, политика, застереження о здоровье,
условия, поддержка — каждая на en/uk/ru) плюс `robots.txt` и `sitemap.xml`, с
canonical и hreflang. Папка статическая, разворачивается на любой хостинг.

Для локального просмотра есть конфигурация `sunfold-site` в
`../.claude/launch.json`.

## Иконка

Исходник художника лежит в `Design/app-icon-source.png` — это скруглённый квадрат
с чёрными углами. Иконка для App Store должна быть полноразмерным квадратом без
скруглений и без альфа-канала (маску накладывает сама iOS). Пересобрать:

```bash
swift Tools/make-appicon.swift Design/app-icon-source.png Sunfold/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Что осталось сделать до сабмита

Порядок подключения покупок — в [docs/RUNBOOK.md](docs/RUNBOOK.md), полный чек-лист сабмита — в [docs/APP-STORE.md](docs/APP-STORE.md). Коротко, это всё
внешние действия, кода они не касаются:

1. ~~Аккаунт Apple Developer~~ — оплачен 2026-08-07
2. ~~Политика приватности и Support URL~~ — опубликованы на GitHub Pages
3. Paid Apps Agreement, банк и налоговые формы (делать первым — самая долгая проверка)
4. Зарегистрировать App Group и оба bundle ID в портале
5. Создать приложение в App Store Connect — этот шаг резервирует имя Sunfold
6. Создать три покупки с ID из `StoreIDs`
7. Аккаунт RevenueCat → ключ в `RCPublicAPIKey`
8. Скриншоты 6.9″

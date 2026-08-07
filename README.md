# Solura

Трекер интервального голодания для iOS. Нативный SwiftUI, всё на устройстве,
без аккаунта и без сервера.

- **Bundle ID:** `app.solura` · виджет `app.solura.widgets`
- **App Group:** `group.app.solura`
- **Минимум:** iOS 17.0 · только iPhone · только портрет
- **Собрано на:** Xcode 26.6, Swift 6 (язык 6.0, `MainActor` по умолчанию)

## Как собрать

```bash
open Solura.xcodeproj
```

Схема `Solura` собирает приложение вместе с расширением виджета. Из терминала:

```bash
xcodebuild -project Solura.xcodeproj -scheme Solura -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
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
Solura/          Только приложение
  App/           Точка входа, RootView с табами
  Features/      Экраны: Timer, History, Weight, Settings, Paywall, Onboarding
  Services/      SwiftData, уведомления, Live Activity, покупки, экспорт
SoluraWidgets/   Только расширение: виджеты + Live Activity
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

**Покупки за абстракцией.** `PurchaseProviding` с двумя реализациями. Если в
`Config/Solura-Info.plist` пустой `RCPublicAPIKey`, подставляется
`UnconfiguredPurchaseProvider`: пейвол показывается с реальными ценами, но
покупка честно падает с ошибкой — ничего не разблокируется молча. Так приложение
разрабатывается и тестируется до создания аккаунта RevenueCat.

**Строки генерируются.** `Shared/Resources/Localizable.xcstrings` собирается из
`Tools/build-strings.py`. После добавления новой строки в коде:

```bash
python3 Tools/build-strings.py
```

Сверить, что в коде нет непереведённых ключей:

```bash
xcodebuild -exportLocalizations -project Solura.xcodeproj -localizationPath /tmp/loc -exportLanguage en
```

и сравнить список ключей из `/tmp/loc/en.xcloc` с таблицей `STRINGS` в скрипте.

## Проверить на своём iPhone

Скачать файл и поставить нельзя — в iOS нет аналога APK. Два рабочих пути
(бесплатно из Xcode по кабелю, либо TestFlight после оплаты $99) с пошаговыми
инструкциями и подвохом про App Groups — в
[docs/TEST-ON-DEVICE.md](docs/TEST-ON-DEVICE.md).

## Иконка

Исходник художника лежит в `Design/app-icon-source.png` — это скруглённый квадрат
с чёрными углами. Иконка для App Store должна быть полноразмерным квадратом без
скруглений и без альфа-канала (маску накладывает сама iOS). Пересобрать:

```bash
swift Tools/make-appicon.swift Design/app-icon-source.png Solura/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

## Что осталось сделать до сабмита

Полный список — в [docs/APP-STORE.md](docs/APP-STORE.md). Коротко, это всё
внешние действия, кода они не касаются:

1. Аккаунт Apple Developer ($99)
2. Аккаунт RevenueCat → ключ в `RCPublicAPIKey`
3. Зарегистрировать App Group и оба bundle ID в портале
4. Создать три покупки в App Store Connect с ID из `StoreIDs`
5. Опубликовать политику приватности на `solura.app/privacy`
6. Скриншоты 6.9″

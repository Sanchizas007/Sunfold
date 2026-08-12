# Чек-лист сабмита Sunfold

Всё, что нужно закрыть до первой отправки в App Store Review. Разбито на то, что
**уже сделано в коде**, и то, что **нужно сделать руками** в порталах Apple и
RevenueCat.

---

## 0. Порядок действий (аккаунт разработчика оплачен 2026-08-07)

Порядок не произвольный: сверху то, что **выполняется не мгновенно**, а значит
должно быть запущено первым, иначе оно станет узким местом в конце.

### Запустить сегодня, всё параллельно

1. **Paid Apps Agreement + банк + налоговые формы.**
   Business → Agreements. Пока соглашение не активно, покупки навсегда висят в
   «Missing Metadata» и **не загружаются в приложении**. Проверка занимает от
   суток до нескольких дней. Это единственный пункт, который реально способен
   сорвать сроки, поэтому он первый.
2. **Домен sunfold.app + выложить `site/`.** Privacy Policy URL — обязательное
   поле, без него приложение не отправить.
3. **App ID `app.sunfold` и `app.sunfold.widgets` + App Group `group.app.sunfold`**
   — раздел 2 ниже.
4. **Создать приложение в App Store Connect.** Именно этот шаг **резервирует имя
   Sunfold** — до него имя ничьё.

### Дальше по цепочке

5. Три покупки в App Store Connect → 6. RevenueCat и ключ в `Info.plist` →
7. Team в Xcode и сборка на живое устройство → 8. Скриншоты и метаданные →
9. Archive → TestFlight → 10. Проверка покупок в песочнице → 11. Submit.

Шаги 5–7 расписаны по кликам в [RUNBOOK.md](RUNBOOK.md), раздел B.

---

## 1. Что уже закрыто в коде

| Требование | Где |
|---|---|
| Privacy manifest приложения | `Sunfold/PrivacyInfo.xcprivacy` |
| Privacy manifest расширения | `SunfoldWidgets/PrivacyInfo.xcprivacy` |
| Required-reason API (UserDefaults, App Group) | Причины `1C8F.1` и `CA92.1` |
| `ITSAppUsesNonExemptEncryption = false` | `Config/Sunfold-Info.plist` — вопрос про экспорт не будет задаваться на каждой сборке |
| Launch screen | `UILaunchScreen` + цвет `LaunchBackground` |
| Категория приложения | `public.app-category.healthcare-fitness` |
| Live Activities | `NSSupportsLiveActivities = true` |
| Медицинский дисклеймер | Онбординг (обязательное подтверждение), `HealthDisclaimerScreen`, экран фаз |
| Политика приватности внутри бинарника | `PrivacyPolicyScreen` — ссылка работает даже если сайт лежит |
| Terms of Use (EULA) | Ссылка на стандартный EULA Apple, `Legal.termsURL` |
| Restore Purchases | Тулбар пейвола + футер |
| Раскрытие автопродления | Прямо над кнопкой покупки, `paywall.terms.subscription` |
| Lifetime помечен как разовый платёж | `paywall.plan.lifetime.detail` |
| Ссылка на управление подпиской | `paywall.manage` → `apps.apple.com/account/subscriptions` |
| Удаление всех данных | Настройки → Удалить все данные |
| Экспорт данных (CSV) | Настройки → Экспорт в CSV |
| Офлайн-работа | Сеть нужна только для покупки; всё остальное локально |
| Запрос уведомлений в нужный момент | Не на запуске, а при старте первого голодания |
| Локализации | en, uk, ru — по три поля ключей ASO |

**Guideline 1.4.1 (вред здоровью).** Это главный риск для приложений про
голодание, поэтому сделано с запасом:
- максимум своего интервала — 48 часов, жёстко в `CustomFastLimits`;
- при цели от 24 часов — алерт с предложением сначала сходить к врачу, до старта;
- во время долгого голодания на экране висит напоминание остановиться при
  недомогании;
- отдельный раздел про расстройства пищевого поведения в дисклеймере;
- фазы метаболизма описаны с оговорками («считается», «приблизительно»), с
  постоянным уведомлением, что это не медицинская информация;
- нигде нет целевого веса, «правильного» веса, ИМТ и осуждающих формулировок;
  прерванное голодание в истории показывается нейтрально, без красного.

---

## 2. Apple Developer Portal

- [ ] Аккаунт Apple Developer, $99/год. **Известный риск:** у украинских
      разработчиков бывают отказы авторизации платежа картой Payoneer — держите
      запасную карту.
- [ ] App ID `app.sunfold` — включить **App Groups**
- [ ] App ID `app.sunfold.widgets` — включить **App Groups**
- [ ] Создать App Group `group.app.sunfold` и привязать к обоим App ID
- [ ] Указать Team в настройках обоих таргетов (сейчас пусто — для симулятора не
      нужно, для устройства обязательно)

> Push-нотификации, HealthKit, Sign in with Apple и associated domains **не
> нужны** — приложение их не использует. Не включайте лишние capability: каждая
> добавляет вопросы на ревью.

---

## 3. RevenueCat

- [ ] Создать проект, добавить приложение iOS с bundle ID `app.sunfold`
- [ ] Скопировать **публичный** ключ (`appl_...`) в `RCPublicAPIKey` в
      `Config/Sunfold-Info.plist`. Он публикуемый, в бинарнике лежать безопасно.
- [ ] Создать entitlement с идентификатором ровно `pro`
- [ ] Создать offering `default` и три пакета, привязанных к продуктам ниже
- [ ] Загрузить App Store Connect API-ключ в RevenueCat (иначе не будет валидации)

Пока ключ пустой: debug-сборка покупает через `Config/Sunfold.storekit` (ничего
не списывается), release-сборка честно отказывается продавать. Ничего не
разблокируется по ошибке ни в одном случае. Подробности — в [RUNBOOK.md](RUNBOOK.md).

---

## 4. App Store Connect: покупки

Идентификаторы должны совпадать с `StoreIDs` в `Sunfold/Services/Purchases.swift`
символ в символ.

| Продукт | ID | Тип | Цена |
|---|---|---|---|
| Sunfold Pro Monthly | `app.sunfold.pro.monthly` | Auto-renewable, группа `sunfold_pro` | $2.99 |
| Sunfold Pro Yearly | `app.sunfold.pro.yearly` | Auto-renewable, та же группа | $14.99 |
| Sunfold Pro Lifetime | `app.sunfold.pro.lifetime` | Non-consumable | $34.99 |

Для каждого — локализованные название и описание на en/uk/ru и скриншот ревью.

> **Про «7 дней»**: это НЕ introductory offer StoreKit, а локальный период
> полного доступа с первого запуска. Поэтому нигде в интерфейсе он не назван
> «бесплатным пробным периодом подписки» — иначе это было бы заявление о
> подписке, которого нет в конфигурации продукта. Если позже захотите настоящий
> intro offer, добавьте его в App Store Connect и уберите локальный период.

---

## 5. App Privacy (ответы в App Store Connect)

Само приложение не собирает ничего. Но в бинарнике есть SDK RevenueCat, поэтому
честные ответы такие — **не отвечайте «Data Not Collected»**:

| Категория | Собирается | Связано с личностью | Для трекинга | Назначение |
|---|---|---|---|---|
| Purchases → Purchase History | Да | Нет | Нет | App Functionality |
| Identifiers → User ID | Да | Нет | Нет | App Functionality |
| Identifiers → Device ID | Да | Нет | Нет | App Functionality |

Всё остальное — нет. Tracking — **нет**, ATT-промпт не нужен.

- [ ] Privacy Policy URL: `https://sunfold.app/privacy/` (обязательное поле)
- [x] Текст политики готов и **уже сгенерирован** в `site/` на трёх языках
      (`python3 Tools/build-site.py`). Он собирается из той же таблицы строк,
      что и экраны приложения, поэтому хостинговая версия дословно совпадает с
      той, что видит ревьюер внутри приложения.
- [ ] Купить домен sunfold.app и выложить содержимое `site/` на любой статический
      хостинг. Нужные адреса: `/privacy/`, `/support/`, `/terms/`, `/health/`.

---

## 6. Возрастной рейтинг

- Medical/Treatment Information: **Infrequent/Mild** (описание фаз метаболизма)
- Всё остальное: None
- Ожидаемый результат — 12+

Не ставьте 4+: приложение прямо адресовано взрослым и в дисклеймере говорит, что
не предназначено для лиц младше 18 без наблюдения врача.

---

## 7. Метаданные и материалы

- [ ] Скриншоты **6.9″** (1320×2868) — единственный обязательный размер для
      iPhone-only приложения. 5–6 штук: таймер до старта, таймер в процессе,
      история со стриком, настройки, вес, фазы.
      **Пейвол и цены не показывать** — решение владельца: цены меняются, а
      каждое изменение скриншота требует нового ревью.
- [ ] Три локализации метаданных: en-US, uk, ru
- [ ] Название, подзаголовок и ключевые слова — в [ASO.md](ASO.md)
- [ ] Support URL: `https://sunfold.app/support`
- [ ] Marketing URL (необязательно)
- [ ] Промо-текст (170 символов, меняется без ревью)

---

## 8. Заметка для ревьюера

Скопировать в поле App Review Information → Notes:

> Sunfold is an offline intermittent fasting timer. There is no account and no
> sign-in, so no demo credentials are needed — all features are reachable
> immediately after the onboarding.
>
> The app opens with seven days of full access. To review the paywall before
> that period ends, tap the badge in the top-right corner of the Timer tab, or
> Settings → Sunfold Pro.
>
> The app is not a medical device and makes no diagnostic or treatment claims.
> A health notice must be acknowledged during onboarding before the app can be
> used, and it remains available in Settings → Health notice. Metabolic phase
> descriptions are presented as approximate, educational information with a
> standing disclaimer. Fasts longer than 24 hours show an additional advisory to
> consult a doctor before starting, and custom fasts are capped at 48 hours.
>
> All data stays on the device. The only network calls are made by the RevenueCat
> SDK to validate purchases.

---

## 9. Перед нажатием Submit

- [ ] Собрать Release и прогнать на **живом устройстве**, не только на симуляторе
      (App Groups и Live Activity на устройстве ведут себя иначе, чем в симуляторе)
- [ ] Проверить покупку в песочнице: покупка, восстановление, отмена
- [ ] Проверить, что ссылки на политику и EULA открываются
- [ ] Проверить виджет и Live Activity на устройстве
- [ ] Проверить приложение в трёх языках (Настройки iOS → Sunfold → Язык)
- [ ] Поднять `CURRENT_PROJECT_VERSION` перед каждой загрузкой

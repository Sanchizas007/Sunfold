# ASO: метаданные Sunfold

> **Про имя.** Первоначальное название Solura пришлось сменить: в App Store уже
> есть опубликованное приложение SOLURA, причём в той же категории «Здоровье и
> фитнес» — это верный отказ по правилам 4.1 и 5.2.1.
>
> Проверять кандидатов можно без аккаунта, публичным поиском:
>
> ```bash
> curl -s --get https://itunes.apple.com/search \
>   --data-urlencode "term=НАЗВАНИЕ" --data-urlencode "entity=software" \
>   --data-urlencode "country=us" | python3 -m json.tool | grep trackName
> ```
>
> ⚠️ Этот API видит только **опубликованные** приложения. Имена, зарезервированные
> в App Store Connect, и торговые марки он не показывает. Окончательная проверка —
> попытка зарезервировать имя в App Store Connect.

Индексируются только **название (30)**, **подзаголовок (30)** и **поле ключевых
слов (100)**. Описание в поиске не участвует — оно работает на конверсию, а не на
выдачу.

Правила, по которым собрано ниже:

- слова из названия и подзаголовка **не дублируются** в ключах — Apple и так их
  индексирует, повтор просто съедает лимит;
- ключи разделены запятыми **без пробелов** — пробел стоит символ;
- множественное число не пишется отдельно, Apple склеивает словоформы;
- у каждой локализации своё поле на 100 символов. Добавление **en-GB** и
  **en-AU** даёт ещё по 100 символов под англоязычные запросы почти без работы —
  тексты можно скопировать из en-US, поменяв только ключи.

---

## en-US

**Название** (29)
```
Sunfold: Intermittent Fasting
```

**Подзаголовок** (27)
```
16:8 fasting timer & phases
```

**Ключевые слова** (97)
```
tracker,18:6,20:4,5:2,ketosis,autophagy,weight,diet,eating,window,hours,log,meal,schedule,counter
```

**Промо-текст** (170)
```
A calm fasting timer that stays on your phone. No account, no ads, no feed — just the ring, your streak, and what your body is doing at hour 14.
```

**Описание**
```
Sunfold is a quiet, warm intermittent fasting tracker. One ring, one number, and
everything you need to know about where you are in your fast.

THE TIMER
Start when you finish your last meal. Sunfold counts from that moment — close the
app, restart your phone, the timer never drifts. A full-screen ring shows how far
along you are, and the metabolic phases are marked around it.

SCHEDULES
16:8, 18:6, 20:4, 5:2, or set your own length from 4 to 48 hours. Change your
schedule mid-fast and the goal moves with you — no need to start over.

METABOLIC PHASES
Watch your fast move from the fed state through early fasting, fat burning,
ketosis and autophagy, with a plain-language explanation of each. Timings are
presented as approximations, because that is what they are.

HISTORY
A streak calendar, total hours, average length, and every fast you have recorded.
Add a note and how the fast felt.

WEIGHT
Optional. Log your weight, see the trend. No goal weight, no BMI, no judgement.

WIDGETS AND DYNAMIC ISLAND
Your timer on the Home Screen, the Lock Screen, and in the Dynamic Island as a
Live Activity, ticking without draining your battery.

REMINDERS
When your fast is complete, thirty minutes before, and when your eating window
closes. All scheduled locally — Sunfold has no push server.

PRIVACY
No account. No sign-in. No analytics, no advertising, no tracking. Everything you
record stays on your device, and you can export it all as CSV or delete it in one
tap.

SUNFOLD PRO
Free forever: the 16:8 schedule and the last seven days of history. Pro unlocks
every schedule, unlimited history, charts, the metabolic phases and widgets.

$2.99/month, $14.99/year, or $34.99 once.

Payment is charged to your Apple ID. Subscriptions renew automatically unless
cancelled at least 24 hours before the period ends, and can be managed in App
Store settings at any time.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://sunfold.app/privacy

IMPORTANT
Sunfold is a timer and a journal, not a medical device. It does not diagnose,
treat or give medical advice. Talk to a doctor before fasting if you are pregnant
or breastfeeding, under 18, living with diabetes or taking medication that
affects blood sugar, taking medicine that must be taken with food, underweight,
or living with a chronic condition. If you have or have had an eating disorder,
please seek support before using a fasting app.
```

---

## uk

**Название** (25)
```
Sunfold: голодування 16:8
```

**Подзаголовок** (27)
```
Таймер посту, фази, історія
```

**Ключевые слова** (91)
```
інтервальний,піст,трекер,18:6,20:4,5:2,кетоз,аутофагія,вага,дієта,вікно,їжі,години,щоденник
```

**Промо-текст**
```
Спокійний таймер голодування, який лишається у вашому телефоні. Без акаунта, без реклами, без стрічки — лише кільце і ваша серія.
```

Описание — перевод en-US. Блок про здоров'я і блок про підписку перекласти
дослівно, вони обов'язкові.

---

## ru

**Название** (23)
```
Sunfold: голодание 16:8
```

**Подзаголовок** (28)
```
Таймер, фазы, история постов
```

**Ключевые слова** (94)
```
интервальное,пост,трекер,18:6,20:4,5:2,кетоз,аутофагия,вес,диета,окно,еды,часы,дневник,счётчик
```

**Промо-текст**
```
Спокойный таймер голодания, который остаётся в вашем телефоне. Без аккаунта, без рекламы, без ленты — только кольцо и ваша серия.
```

Описание — перевод en-US.

---

## Что проверить через месяц после релиза

Так же, как делалось с лендингом ShiftQ: собрать реальные запросы из App Store
Connect → Analytics → **Search Terms** и пересобрать поля ключей по фактам, а не
по догадкам. Гадание на старте — это только гипотеза.

Отдельно посмотреть **Impressions → Conversion Rate** по локализациям: если
украинская или русская выдача даёт показы, но не даёт установок, проблема в
первом скриншоте, а не в ключах.

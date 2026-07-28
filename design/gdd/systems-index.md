# Systems Index

> Last Updated: 2026-07-28
> Engine: Godot 4.7 (GDScript)
> Source: ported from `DYRM Docs/ГДД - Перечень систем.md` v0.2 during full adoption
> of the gamedev plugin — see `docs/adoption-plan-2026-07-28.md`. Groupings, numbers
> and priority tags (MVP/Core/Ext) are carried over unchanged; only the Layer and
> Status columns and the Design Order are new, added for the plugin's own use.

## Naming Convention (project-specific, keep using this)

DYRM numbers systems as `NNN` = the GDD dotted number with the dot removed
(`0.1`→`001`, `2.7`→`027`, a whole block→`000`) — this predates the plugin and is
kept for continuity with references already embedded in shipped code
(`# FR-12`, `TODO(ТЗ-027)`) and in the two already-written specs. **GDD filenames in
this project are `design/gdd/NNN-kebab-case-name.md`**, not bare `kebab-case-name.md`
— e.g. `design/gdd/027-navedenie-lazera.md`. When `/design-system` or `/map-systems`
ask for "the system name", give it as `NNN-kebab-case-name` so the file lands with
the right prefix.

Two systems were designed as combined documents pre-adoption and stay that way:
- **000** = 0.1 Станция + 0.2 Окружающий космос (one document, ТЗ-000)
- **100** = 1.1 Перемещение + 1.2 Панели (one document, ТЗ-100 — subsystem numbers
  011/012 were considered in early drafts and explicitly retired, never reused)

## Progress Tracker

| Priority | Total | Approved | Designed | Not Started |
|----------|-------|----------|----------|-------------|
| MVP | 20 | 2 (000, 100) | 0 | 18 |
| Core | 19 | 0 | 0 | 19 |
| Ext | 14 | 0 | 0 | 14 |
| **Total** | **53** | **2** | **0** | **51** |

## Block 0 — Игровое окружение

| ID | System | Layer | Priority | Status | Design Doc |
|----|--------|-------|----------|--------|------------|
| 000 | Станция + Окружающий космос (0.1, 0.2) | Foundation | MVP | Approved | `design/gdd/000-igrovoe-okruzhenie.md` |

## Block 1 — Игрок и станция от первого лица

| ID | System | Layer | Priority | Status | Design Doc |
|----|--------|-------|----------|--------|------------|
| 100 | Перемещение от первого лица + Панели (1.1, 1.2) | Foundation | MVP | Approved | `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md` |
| 013 | Жизнеобеспечение и выживание оператора | Core | Ext | Not Started | — |
| 014 | Выход в открытый космос (EVA) | Core | Ext | Not Started | — |
| 015 | Звук и аудиосигналы | Core | Core | Not Started | — |

## Block 2 — Ядро геймплея: обработка сигнала

| ID | System | Layer | Priority | Status | Design Doc |
|----|--------|-------|----------|--------|------------|
| 021 | Приём входящих сообщений | Core | MVP | Not Started | — |
| 022 | Дешифровка и декодирование | Core | Core | Not Started | — |
| 023 | Адресация и определение получателя | Core | MVP | Not Started | — |
| 024 | Документация и справочники | Core | MVP | Not Started | — |
| 025 | Звёздная 3D-карта и навигация | Core | MVP | Not Started | — |
| 026 | Каталог ретрансляторов и сети | Core | Core | Not Started | — |
| 027 | Наведение лазера | Core | MVP | Not Started | — |
| 028 | Захват цели | Core | MVP | Not Started | — |
| 029 | Передача сигнала | Core | MVP | Not Started | — |

## Block 3 — Оборудование станции

| ID | System | Layer | Priority | Status | Design Doc |
|----|--------|-------|----------|--------|------------|
| 031 | Лазерные установки | Core | MVP | Not Started | — |
| 032 | Режимы работы лазеров | Core | Core | Not Started | — |
| 033 | Диапазоны и частоты связи | Core | Core | Not Started | — |
| 034 | Приёмные антенны | Core | Core | Not Started | — |
| 035 | Энергоснабжение станции | Core | Core | Not Started | — |
| 036 | Состояние и износ оборудования | Core | Core | Not Started | — |
| 037 | Температура и перегрев | Core | Core | Not Started | — |
| 038 | Ремонт и обслуживание | Core | Core | Not Started | — |
| 039 | Управление станцией | Core | Core | Not Started | — |
| 310 | Ресурсы и расходники | Core | Ext | Not Started | — |

## Block 4 — Нагрузка, время и события

| ID | System | Layer | Priority | Status | Design Doc |
|----|--------|-------|----------|--------|------------|
| 041 | Очередь задач и многозадачности | Feature | MVP | Not Started | — |
| 042 | Таймеры и приоритеты | Feature | MVP | Not Started | — |
| 043 | Типы сигналов | Feature | MVP | Not Started | — |
| 044 | Помехи и шум | Feature | Core | Not Started | — |
| 045 | Аварийные события | Feature | Core | Not Started | — |
| 046 | Космические угрозы | Feature | Core | Not Started | — |
| 047 | Изменяющаяся топология сети | Feature | Core | Not Started | — |
| 048 | Маршрутизация и обходные пути | Feature | Core | Not Started | — |
| 049 | Рабочие смены и расписание сети | Feature | Ext | Not Started | — |

## Block 5 — Ошибки, оценка и прогрессия

| ID | System | Layer | Priority | Status | Design Doc |
|----|--------|-------|----------|--------|------------|
| 051 | Ошибки и последствия | Feature | MVP | Not Started | — |
| 052 | Оценка качества работы (KPI) | Feature | MVP | Not Started | — |
| 053 | Репутация и начальство | Feature | Core | Not Started | — |
| 054 | Смена фаз (работа/отдых) | Feature | MVP | Not Started | — |
| 055 | Обучение и постепенное усложнение | Feature | MVP | Not Started | — |
| 056 | Экономика станции | Feature | Ext | Not Started | — |
| 057 | Улучшения станции и оборудования | Feature | Ext | Not Started | — |
| 058 | Достижения | Feature | Ext | Not Started | — |

## Block 6 — Нарратив и мир

| ID | System | Layer | Priority | Status | Design Doc |
|----|--------|-------|----------|--------|------------|
| 061 | Сюжет и кампания | Polish | Ext | Not Started | — |
| 062 | Персонажи и внешняя коммуникация | Polish | Ext | Not Started | — |
| 063 | Лор и мировые события | Polish | Ext | Not Started | — |

## Block 7 — Режимы, контент и мета-системы

| ID | System | Layer | Priority | Status | Design Doc |
|----|--------|-------|----------|--------|------------|
| 071 | Сценарии и уровни | Feature | Core | Not Started | — |
| 072 | Процедурная генерация | Polish | Ext | Not Started | — |
| 073 | Сохранение и прогресс | Foundation | MVP | Not Started | — |
| 074 | Настройки и доступность | Feature | Core | Not Started | — |
| 075 | Редактор сценариев | Polish | Ext | Not Started | — |
| 076 | Бесконечный режим | Polish | Ext | Not Started | — |
| 077 | Мультиплеер (гипотеза) | Polish | Ext | Not Started | — |

## Recommended Design Order (remaining MVP systems)

Derived from the "Блокирует ТЗ" / "Зависит от ТЗ" fields already declared in ТЗ-000
and ТЗ-100 (not a new dependency analysis — carrying forward what was already
decided), Foundation → Core → Feature:

1. **021** Приём входящих сообщений
2. **024** Документация и справочники
3. **023** Адресация и определение получателя
4. **025** Звёздная 3D-карта и навигация
5. **027** Наведение лазера
6. **028** Захват цели
7. **031** Лазерные установки
8. **029** Передача сигнала
9. **039** Управление станцией
10. **073** Сохранение и прогресс
11. **013** Жизнеобеспечение и выживание оператора
12. **014** Выход в открытый космос (EVA)
13. **015** Звук и аудиосигналы (tagged Core priority, but ТЗ-100 already treats its signals as a first-class dependency — design early)
14. **041** Очередь задач и многозадачности
15. **042** Таймеры и приоритеты
16. **043** Типы сигналов
17. **051** Ошибки и последствия
18. **052** Оценка качества работы (KPI)
19. **054** Смена фаз (работа/отдых)
20. **055** Обучение и постепенное усложнение

Core- and Ext-tagged systems follow after all MVP systems are designed, per
`/map-systems`'s standard tiering (MVP → Vertical Slice → Alpha → Full Vision).

## High-Risk / Bottleneck Systems

- **026** (Каталог ретрансляторов и сети) — many downstream systems (048 маршрутизация,
  047 топология, 025 звёздная карта) depend on its data model; get this right early.
- **033** (Диапазоны и частоты связи) — cross-cuts 021, 022, 031, 032, 043; changing
  it late touches many systems at once.

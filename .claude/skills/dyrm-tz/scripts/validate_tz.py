#!/usr/bin/env python3
"""Механическая проверка ТЗ-документа DYRM.

Проверяет то, что можно проверить без понимания смысла:
покрытие требований критериями, уникальность и целостность ID,
баланс код-блоков, самодостаточность промта, согласованность
файловых деревьев раздела 8 и промта.

Смысловая часть — чек-лист раздела 14 шаблона — проходится глазами.

Использование:
    python3 validate_tz.py "ТЗ-000 — Игровое окружение.md"
Код возврата: 0 — ошибок нет, 1 — есть ошибки.
"""

import re
import sys
from pathlib import Path

ERRORS: list[str] = []
WARNINGS: list[str] = []
INFO: list[str] = []


def err(msg: str) -> None:
    ERRORS.append(msg)


def warn(msg: str) -> None:
    WARNINGS.append(msg)


def info(msg: str) -> None:
    INFO.append(msg)


# --- разбор --------------------------------------------------------------

def defined_ids(text: str, prefix: str) -> list[str]:
    """ID, определённые как первая ячейка строки таблицы."""
    return re.findall(rf"^\|\s*{prefix}-(\d+)\s*\|", text, re.MULTILINE)


def mentioned_ids(text: str, prefix: str) -> set[str]:
    return set(re.findall(rf"\b{prefix}-(\d+)\b", text))


def section(text: str, start: str, end: str) -> str:
    i = text.find(start)
    if i < 0:
        return ""
    j = text.find(end, i + len(start))
    return text[i:j if j > 0 else len(text)]


# --- проверки ------------------------------------------------------------

def check_ids(text: str) -> None:
    for prefix in ("FR", "NFR", "AC", "R", "Q", "DM"):
        defined = defined_ids(text, prefix)
        dupes = {x for x in defined if defined.count(x) > 1}
        if dupes:
            err(f"{prefix}: дублирующиеся ID: {sorted(dupes, key=int)}")
        undefined = mentioned_ids(text, prefix) - set(defined)
        if undefined:
            err(f"{prefix}: упомянуты, но не определены: {sorted(undefined, key=int)}")
        if defined:
            info(f"{prefix}: определено {len(defined)}")


def check_coverage(text: str) -> None:
    """Каждое FR должно упоминаться в колонке «Покрывает» таблицы критериев."""
    fr_defined = set(defined_ids(text, "FR"))
    if not fr_defined:
        warn("Не найдено ни одного FR — раздел 4 не заполнен?")
        return
    covered: set[str] = set()
    for line in text.splitlines():
        if not line.lstrip().startswith("| AC-"):
            continue
        cells = [c.strip() for c in line.split("|")]
        if len(cells) >= 3:
            covered |= set(re.findall(r"FR-(\d+)", cells[-2]))
    uncovered = fr_defined - covered
    if uncovered:
        err(f"FR без критерия приёмки: {sorted(uncovered, key=int)}")
    else:
        info(f"Все {len(fr_defined)} FR покрыты критериями приёмки")


def check_open_questions(text: str) -> None:
    """У каждого открытого вопроса должно быть решение по умолчанию."""
    rows = re.findall(r"^\|\s*Q-(\d+)\s*\|(.+)$", text, re.MULTILINE)
    for num, rest in rows:
        cells = [c.strip() for c in rest.split("|")]
        while cells and not cells[-1]:      # хвостовая пустая ячейка от закрывающей |
            cells.pop()
        if not cells or cells[-1] in {"-", "—"}:
            err(f"Q-{num}: не задано решение по умолчанию")
    if rows:
        info(f"Открытых вопросов: {len(rows)}")


def check_fences(text: str) -> None:
    if text.count("````") % 2 != 0:
        err("Непарный четырёхкавычный блок (````)")
    stripped = text.replace("````", "")
    if stripped.count("```") % 2 != 0:
        err("Непарный трёхкавычный блок (```)")


def check_prompt(text: str) -> str:
    i = text.find("````")
    if i < 0:
        err("Промт не найден: в разделе 13 нет блока с ````")
        return ""
    j = text.find("````", i + 4)
    if j < 0:
        err("Промт не закрыт")
        return ""
    prompt = text[i + 4:j]

    if len(prompt) < 2000:
        warn(f"Промт подозрительно короткий ({len(prompt)} символов)")
    else:
        info(f"Длина промта: {len(prompt)} символов")

    # Промт не должен ссылаться на документ вокруг себя.
    leaks = re.findall(
        r"(?:см\.|смотри|согласно|по)\s+(?:раздел\w*|п\.|пункт\w*|табл\w*)\s*\d",
        prompt, re.IGNORECASE)
    if leaks:
        err(f"Промт ссылается на разделы документа (нарушена самодостаточность): {leaks[:5]}")

    # Обязательные блоки.
    required = {
        "запреты": r"НЕЛЬЗЯ|НЕ\s+реализуеш|Чего\s+делать\s+нельзя",
        "порядок работы по этапам": r"Порядок работы|по этапам|Э1",
        "поведение при неоднозначности": r"неоднозначност",
        "требование отчёта": r"Отчёт|отчёт по завершении",
    }
    for label, pattern in required.items():
        if not re.search(pattern, prompt, re.IGNORECASE):
            err(f"В промте отсутствует обязательный блок: {label}")

    # MCP описан слишком подробно?
    tool_calls = re.findall(
        r"\b(take_screenshot|simulate_input|run_script|get_ui_elements|"
        r"add_node|set_node_properties|batch_scene_operations|attach_project|"
        r"get_scene_tree|connect_signal|responseMode|bridgePort)\b", prompt)
    if tool_calls:
        err("Промт содержит имена MCP-инструментов или их параметры "
            f"(должны быть только архитектурные следствия): {sorted(set(tool_calls))}")

    return prompt


def check_file_trees(text: str, prompt: str) -> None:
    pat = r"[\w./-]+\.(?:gd|tscn|tres|gdshader|godot|svg|md|py|json|cfg)"
    doc_tree = section(text, "## 8. Файловая структура", "## 9.")
    doc_files = {Path(m).name for m in re.findall(pat, doc_tree)}
    prompt_files = {Path(m).name for m in re.findall(pat, prompt)}
    if not doc_files:
        warn("Раздел 8 пуст или не найден")
        return
    missing = doc_files - prompt_files
    # Файлы, перечисленные в промте свёрнуто (через «и т. п.»), отсеиваем по расширению.
    missing = {f for f in missing if not f.endswith(".tres")}
    if missing:
        warn(f"Есть в разделе 8, но не упомянуты в промте: {sorted(missing)}")
    extra = prompt_files - doc_files
    if extra:
        warn(f"Есть в промте, но не в разделе 8: {sorted(extra)}")


def check_hints_removed(text: str) -> None:
    hints = re.findall(r"^>\s*💡", text, re.MULTILINE)
    if hints:
        err(f"В документе остались подсказки шаблона (> 💡): {len(hints)} шт. — удалить")


def check_passport(text: str) -> None:
    for field in ("ID документа", "Система по ГДД", "Приоритет по ГДД",
                  "Версия документа", "Статус", "Зависит от ТЗ", "Блокирует ТЗ"):
        if field not in text:
            err(f"В паспорте отсутствует поле: {field}")
    if re.search(r"^\|\s*\*\*(?!.*\|\s*\S).*\|\s*\|\s*$", text, re.MULTILINE):
        warn("В паспорте есть незаполненные поля")


def check_mcp_section(text: str) -> None:
    if "7.7" not in text and "MCP" not in text:
        warn("Нет раздела об инструментальной среде (7.7) — это ожидаемо только "
             "для систем без кодовой реализации")


# --- запуск --------------------------------------------------------------

def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    path = Path(sys.argv[1])
    if not path.exists():
        print(f"Файл не найден: {path}")
        return 2
    text = path.read_text(encoding="utf-8")

    check_passport(text)
    check_hints_removed(text)
    check_ids(text)
    check_coverage(text)
    check_open_questions(text)
    check_fences(text)
    prompt = check_prompt(text)
    if prompt:
        check_file_trees(text, prompt)
    check_mcp_section(text)

    print(f"=== {path.name} ===\n")
    for line in INFO:
        print(f"  ok    {line}")
    if WARNINGS:
        print()
        for line in WARNINGS:
            print(f"  warn  {line}")
    if ERRORS:
        print()
        for line in ERRORS:
            print(f"  ОШИБКА {line}")

    print(f"\nИтог: ошибок {len(ERRORS)}, предупреждений {len(WARNINGS)}")
    print("Механическая проверка пройдена. Чек-лист раздела 14 — вручную."
          if not ERRORS else "Исправить ошибки и прогнать заново.")
    return 1 if ERRORS else 0


if __name__ == "__main__":
    sys.exit(main())

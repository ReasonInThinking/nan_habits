# ⚡ NanHabits

Лёгкий и быстрый трекер привычек на Flutter для **Linux (x86_64)**. ✨

<img width="1283" height="754" alt="nan-habits" src="https://github.com/user-attachments/assets/189714bd-b390-4d84-8cc8-b2467994189d" />


## ✨ Возможности

- 🔮 **Фокус на текущем дне:** спокойный минималистичный интерфейс с радиальным кольцом прогресса — ничего лишнего, только сегодняшняя задача и кнопка **«Выполнить сегодня»**.
- ⏳ **Умный «Кэш» до завтра:** после отметки привычка уходит в отдельную вкладку **Кэш**, освобождая экран, и автоматически возвращается в активные на следующий календарный день.
- 🌀 **Орбитальная навигация:** переключение между невыполненными на сегодня задачами с помощью боковых лепестков-стрелок, свайпов или колесика мыши.
- 🧲 **Магнитный док справа:** быстрое переключение между тремя состояниями — **Актив** (на сегодня), **Кэш** (отдыхают до завтра) и **Архив** (завершённые циклы).
- 🚀 **Командная консоль:** быстрое добавление новых привычек с выбором длительности цикла (`7 / 14 / 21 / 30 / 60 дн.`).
- 💾 **Локальное хранение:** весь прогресс автоматически сохраняется в файл `~/.nan_habits_v2.json`.


## 📦 Быстрая установка (Linux x86_64)

### 1. Скачивание файлов ⬇

1. Скачайте **NanHabits-x86_64.AppImage** из раздела **Releases**.
2. Сохраните файл **logo.png** из репозитория в ту же папку (например, `~/Documents/NanHabits`).

### 2. Добавление в меню приложений и запуск из терминала 🖥

Выполните скрипт в терминале для автоматического создания ярлыка и команды `nanhabits`:

```bash
python3 -c '
import os, glob, shutil, subprocess

matches = sorted(glob.glob(os.path.expanduser("~/**/NanHabits-x86_64.AppImage"), recursive=True))
if not matches:
    print("Файл NanHabits-x86_64.AppImage не найден в домашней папке")
    exit(1)

app_path = matches.pop(0)
app_dir = os.path.dirname(app_path)
os.chmod(app_path, 0o755)

bin_dir = os.path.expanduser("~/.local/bin")
os.makedirs(bin_dir, exist_ok=True)
bin_file = os.path.join(bin_dir, "nanhabits")
with open(bin_file, "w") as f:
    f.write(f"""#!/bin/sh
nohup env GDK_BACKEND=x11 "{app_path}" >/dev/null 2>&1 &
""")
os.chmod(bin_file, 0o755)

icons_dir = os.path.expanduser("~/.local/share/icons")
os.makedirs(icons_dir, exist_ok=True)
icon_dest = os.path.join(icons_dir, "nanhabits.png")
logo_src = os.path.join(app_dir, "logo.png")
if os.path.exists(logo_src):
    shutil.copy2(logo_src, icon_dest)

desktop_dir = os.path.expanduser("~/.local/share/applications")
os.makedirs(desktop_dir, exist_ok=True)
desktop_file = os.path.join(desktop_dir, "nanhabits.desktop")
with open(desktop_file, "w") as f:
    f.write(f"""[Desktop Entry]
Type=Application
Name=NanHabits
Comment=Трекер привычек с орбитальной колодой
Exec={bin_file}
Icon={icon_dest}
Categories=Utility;Office;
Terminal=false
StartupWMClass=nan_habits
""")
os.chmod(desktop_file, 0o755)
subprocess.run(["update-desktop-database", desktop_dir])

bashrc = os.path.expanduser("~/.bashrc")
if os.path.exists(bashrc):
    content = open(bashrc).read()
    if ".local/bin" not in content:
        with open(bashrc, "a") as f:
            f.write("\nexport PATH=\"HOME/.local/bin:PATH\"\n")

print("Готово! Ярлык создан, запуск из терминала: nanhabits")
'
```

Запуск программы возможен из меню или через терминал:

```bash
nanhabits
```

## ⭐ Поддержка проекта

Поддержите проект звёздочкой в репозитории! 🙌

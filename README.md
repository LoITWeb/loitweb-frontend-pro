# 🌟 LoITWeb Frontend PRO Scaffold (Installer Script)

RU:
Этот проект — современная профессиональная сборка **LoITWeb Frontend PRO** на Gulp 5.
Создана для быстрой разработки высокопроизводительных фронтенд-проектов.

---

## 🚀 Начало работы (Getting Started)

Этот репозиторий содержит **скрипт-установщик** (`init_project.sh`), который создает полный шаблон сборки **LoITWeb Frontend PRO** на вашем локальном компьютере.

### Шаг 1: Скачивание и Подготовка

1.  **Скачайте ZIP-архив** с кодом, нажав зеленую кнопку "Code" на странице GitHub и выбрав "Download ZIP".
2.  Распакуйте архив на вашем компьютере. По умолчанию папка будет называться `loitweb-frontend-pro-main`.
3.  **Переименуйте папку** (например, в `my-new-project`) и перейдите в нее:
    ```bash
    cd my-new-project 
    ```

### Шаг 2: Инициализация

Запустите скрипт для создания всей структуры сборки и установки зависимостей:

```bash
chmod +x init_project.sh
./init_project.sh

Особенности:
1. **Esbuild:**
   - Используйте `import/export` в JS.
   - Точка входа: `src/scripts/main.js`.
   
2. **Производительность:**
   - Картинки сжимаются, только если они изменились (`gulp-newer`).
   
3. **WebP в SRC:**
   - При конвертации картинок, WebP копии сохраняются в папке `src` рядом с оригиналами (чтобы их можно было видеть в IDE), и дублируются в `dist`.

4. **Cache Busting (Build только):**
   - При `npm run build` к CSS/JS добавляются версии (e.g. `main.css?v=2348923`).

5. **Пути:**
   - Пути в HTML/SCSS автоматически правятся под dist.
   
6. **Структура:**
   - Внедрен `.wrapper` для прижатия футера (Sticky Footer) и контроля overflow.

7. **Важное замечание по Background-изображениям (CSS):**
   Для фоновых изображений в SCSS необходимо использовать абсолютные пути, 
   начинающиеся от корня `dist` (корня проекта/сервера), 
   чтобы избежать проблем с относительными путями (`../`) после компиляции CSS.
   НЕПРАВИЛЬНО: `url(./../SubBanner/images/image.webp);`
   ПРАВИЛЬНО: `url(/images/Home/SubBanner/image.webp);`

### ⚙️ Команды

- `chmod +x init_project.sh` → Делает файл исполняемым.
- `./init_project.sh` → Запускает инициализацию проекта и создаёт структуру.
- `npm run dev` → Запускает режим разработки: локальный сервер, live reload, сборка скриптов/стилей.
- `npm run build` → Делает финальную сборку проекта для продакшена: оптимизация, минификация, cache busting.
- `npm run clean` → Удаляет папки dist/build.
- `npm update` → Обновляет NPM-зависимости.

---
### 👤 Авторство и Контакты

Этот проект был разработан и поддерживается **Андреем Ло (Andrey Lo)**.

* **Автор:** [Andrey Lo](https://www.loitweb.com/) (Псевдоним)
* **Веб-сайт:** [Loitweb.com](https://www.loitweb.com/)
* **GitHub:** [LoITWeb](https://github.com/LoITWeb)
* **Лицензия:** [MIT License](LICENSE)

***

# 🌟 LoITWeb Frontend PRO Scaffold (Installer Script)

EN:
This project is a modern, professional build system, **LoITWeb Frontend PRO** based on Gulp 5.
It is created for the rapid development of high-performance frontend projects.

---

## 🚀 Getting Started

This repository contains an **installer script** (`init_project.sh`) that creates the full **LoITWeb Frontend PRO** build template on your local machine.

### Step 1: Download and Preparation

1.  **Download the ZIP file** containing the code by clicking the green "Code" button on the GitHub page and selecting "Download ZIP."
2.  Extract the archive on your computer. The default folder will be named `loitweb-frontend-pro-main`.
3.  **Rename the folder** (e.g., to `my-new-project`) and navigate into it:
    ```bash
    cd my-new-project 
    ```

### Step 2: Initialization

Run the script to create the full build structure and install dependencies:

```bash
chmod +x init_project.sh
./init_project.sh

Features:
1. **Esbuild:**
   -Use `import/export` syntax in JavaScript.
   -Entry point: `src/scripts/main.js`.

2. **Performance:**
   -Images are compressed only if they were changed (gulp-newer).

3. **WebP in SRC:**
   -Converted WebP images are saved back to `src` (for IDE visibility) and also to `dist`.

4. **Cache Busting (Build only):**
   -During npm run build, CSS/JS files receive version hashes (e.g., main.css?v=2348923).

5. **Path Fixing:**
   -HTML and SCSS paths are automatically rewritten to match the dist structure.

6. **Structure:**
   -A .wrapper layout is included to support a sticky footer and control overflow behavior.

7. **Important Note on Background Images (CSS):**
   For CSS background images in SCSS, you must use absolute paths 
   starting from the `dist` root (the project/server root).
   This is necessary to avoid issues with relative paths (`../`) after the CSS compilation.
   INCORRECT: `url(./../SubBanner/images/image.webp);`
   CORRECT: `url(/images/Home/SubBanner/image.webp);`

### ⚙️ Commands

- `chmod +x init_project.sh` → Makes the file executable.
- `./init_project.sh` → Runs the project initialization script.
- `npm run dev` → Starts the development mode: local server, live reload, JS/CSS building.
- `npm run build` → Builds the project for production: optimization, minification, cache busting.
- `npm run clean` → Removes dist/build folders.
- `npm update` → Updates NPM dependencies.

---
### 👤 Attribution & Contact

This project is created and maintained by **Andrey Lo**.

* **Author:** [Andrey Lo](https://www.loitweb.com/) (Pseudonym)
* **Website:** [Loitweb.com](https://www.loitweb.com/)
* **GitHub:** [LoITWeb](https://github.com/LoITWeb)
* **License:** [MIT License](LICENSE)

***

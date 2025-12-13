#!/usr/bin/env bash
# init_project.sh
# Created by Andrey Lo (https://www.loitweb.com/)
# My GitHub (https://github.com/LoITWeb)
# Modern Gulp 5 scaffold
# FEATURES:
# - Gulp Newer (Incremental builds for images)
# - Esbuild (Modern JS with imports)
# - Version Number (Cache busting for CSS/JS)
# - Smart Fonts & Path Fixes
# - Global Wrapper structure (Sticky Footer ready)
# - WebP generation back to SRC folder

set -euo pipefail

# ---------------- Config ----------------
PROJECT_NAME="$(basename "$PWD")"
NODE_VERSION="24"
PROJECT_DIR="$(pwd)"

echo
echo "Init script — creating project: ${PROJECT_NAME}"
echo "Running in: ${PROJECT_DIR}"
echo "Author: Andrey Lo (https://www.loitweb.com/)"
echo

# ---------------- Safety check ----------------
if [ -e "${PROJECT_DIR}/package.json" ] || [ -e "${PROJECT_DIR}/gulpfile.mjs" ]; then
  echo "Warning: package.json or gulpfile.mjs already exist."
  read -p "Proceed and overwrite? (y/N) " PROCEED
  PROCEED=${PROCEED:-N}
  if [[ ! "${PROCEED}" =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# --------------- Helpers ----------------
write() {
  local target="$1"; shift
  mkdir -p "$(dirname "$target")"
  cat > "$target"
}

mkdirp() {
  mkdir -p "$@"
}

# ---------------- Create directories ----------------
echo "Creating directories..."
mkdirp src/public/images
mkdirp src/public/favicons

# component placeholders
mkdirp src/components/common/Header/images
mkdirp src/components/common/Footer/images
mkdirp src/components/Home/Hero/images

mkdirp src/scripts
mkdirp src/scss
mkdirp src/fonts

# dist/build
mkdirp dist
mkdirp build

# ---------------- .nvmrc ----------------
echo "${NODE_VERSION}" > .nvmrc

# ---------------- .gitignore ----------------
cat > .gitignore <<'GIT'
node_modules/
dist/
build/
.DS_Store
.vscode/
package-lock.json
src/**/images/*.webp
!src/**/images/keep.webp
GIT

# Note: I added src webp ignore to gitignore above, just in case you don't want generated files in git. 
# You can remove that line if you want to commit generated webp files.

# =====================================================================
# GULPFILE (gulpfile.mjs)
# =====================================================================

echo "Creating Gulpfile (gulpfile.mjs)..."

write gulpfile.mjs <<'GULP'
import gulp from "gulp";
import dartSass from "sass";
import gulpSass from "gulp-sass";
import fileInclude from "gulp-file-include";
import imagemin from "gulp-imagemin";
import webp from "gulp-webp";
import rename from "gulp-rename";
import autoprefixer from "gulp-autoprefixer";
import plumber from "gulp-plumber";
import fs from "fs";
import path from "path";
import browserSyncModule from "browser-sync";
import { exec } from "child_process";
import fonter from "gulp-fonter";
import ttf2woff from "gulp-ttf2woff";
import ttf2woff2 from "gulp-ttf2woff2";
import { deleteAsync } from "del";
import merge from "merge-stream";
import sourcemaps from "gulp-sourcemaps";
import cleanCSS from "gulp-clean-css";
import htmlmin from "gulp-htmlmin";
import replace from "gulp-replace";

// --- NEW IMPORTS ---
import newer from "gulp-newer";
import gulpEsbuild from "gulp-esbuild";
import versionNumber from "gulp-version-number";

const browserSync = browserSyncModule.create();
const sass = gulpSass(dartSass);

let OUT = "dist"; 

const paths = {
  html: {
    src: "src/*.html",
    dest: () => `${OUT}/`,
  },
  styles: {
    src: "src/scss/main.scss",
    dest: () => `${OUT}/css/`,
  },
  scripts: {
    // Esbuild needs a single entry point to bundle everything
    src: "src/scripts/main.js",
    watch: "src/scripts/**/*.js", // Watch all files for changes
    dest: () => `${OUT}/js/`,
  },
  images: {
    publicFaviconsSrc: "src/public/favicons/**/*",
    publicImagesSrc: "src/public/images/**/*.{png,jpg,jpeg,svg,gif,webp}",
    publicImagesWebpSrc: "src/public/images/**/*.{png,jpg,jpeg}",
    componentsSrc: "src/components/**/images/**/*.{png,jpg,jpeg,svg,gif,webp}",
    componentsWebpSrc: "src/components/**/images/**/*.{png,jpg,jpeg}",
    dest: () => `${OUT}/images/`,
  },
  fonts: {
    srcOtf: "src/fonts/*.otf",
    srcTtf: "src/fonts/*.ttf",
    allSrc: "src/fonts/*.{ttf,otf,woff,woff2}",
    dest: () => `${OUT}/fonts/`,
    scssOut: "src/scss/_fonts.scss"
  },
};

// Helper: write file only if changed
function writeIfChanged(filePath, content) {
  try {
    if (fs.existsSync(filePath)) {
      const existing = fs.readFileSync(filePath, "utf8");
      if (existing === content) return false; 
    } else {
      fs.mkdirSync(path.dirname(filePath), { recursive: true });
    }
    fs.writeFileSync(filePath, content, "utf8");
    return true;
  } catch (e) {
    try { fs.writeFileSync(filePath, content, "utf8"); return true; } catch (ee) { return false; }
  }
}

// ------------------ SCSS Auto Imports ------------------
export function generateComponentsAuto(done) {
  const componentsDir = "src/components";
  let imports = "";

  function scan(dir) {
    let items = [];
    try { items = fs.readdirSync(dir); } catch (e) { return; }
    for (const item of items) {
      const full = path.join(dir, item);
      let stat;
      try { stat = fs.statSync(full); } catch (e) { continue; }
      if (stat.isDirectory()) scan(full);
      else if (/^_.*\.scss$/.test(item)) {
        const rel = path.relative("src/scss", full).replace(/\\/g, "/");
        const mod = rel.slice(0, -5);
        imports += `@use "${mod}";\n`;
      }
    }
  }

  scan(componentsDir);
  const changed = writeIfChanged("src/scss/_components-auto.scss", imports);
  if (changed) console.log("✅ SCSS components imported (updated).");
  done();
}

// ------------------ Fonts ------------------
const weightMap = {
  "thin": 100, "hairline": 100, "extralight": 200, "extra light": 200, "light": 300,
  "regular": 400, "normal": 400, "medium": 500, "semibold": 600, "semi bold": 600,
  "bold": 700, "extrabold": 800, "extra bold": 800, "black": 900, "heavy": 900
};

function convertOtfToTtf() {
  return gulp.src(paths.fonts.srcOtf, { allowEmpty: true, encoding: false })
    .pipe(plumber())
    .pipe(fonter({ formats: ["ttf"] }))
    .pipe(gulp.dest("src/fonts/"));
}

function convertTtfToWebFonts() {
  const ttf = gulp.src(paths.fonts.srcTtf, { allowEmpty: true, encoding: false }).pipe(plumber());
  return merge(
    ttf.pipe(ttf2woff()).pipe(gulp.dest(paths.fonts.dest())),
    gulp.src(paths.fonts.srcTtf, { allowEmpty: true, encoding: false }).pipe(ttf2woff2()).pipe(gulp.dest(paths.fonts.dest()))
  );
}

export function generateFontsScss(done) {
  const dir = paths.fonts.dest();
  let files = [];
  try { if (fs.existsSync(dir)) files = fs.readdirSync(dir); } catch (e) { files = []; }

  const map = {};
  for (const f of files) {
    const ext = path.extname(f).toLowerCase();
    const filename = path.basename(f, ext);
    if (ext !== '.woff' && ext !== '.woff2') continue;
    if (!map[filename]) map[filename] = { name: filename, woff: null, woff2: null };
    if (ext === ".woff2") map[filename].woff2 = f;
    if (ext === ".woff") map[filename].woff = f;
  }

  let out = "";
  for (const key of Object.keys(map)) {
    const entry = map[key];
    const fullFileName = entry.name;
    let fontFamily = fullFileName;
    let fontWeight = 400;
    let fontStyle = "normal";

    if (fullFileName.includes("-")) {
      const parts = fullFileName.split("-");
      const suffix = parts.pop(); 
      fontFamily = parts.join("-");
      const lowerSuffix = suffix.toLowerCase();
      if (lowerSuffix.includes("italic")) fontStyle = "italic";
      const weightKey = lowerSuffix.replace("italic", "").trim();
      if (weightMap[weightKey]) fontWeight = weightMap[weightKey];
    } else {
      fontFamily = fullFileName;
      if (fontFamily.toLowerCase().includes("italic")) fontStyle = "italic";
    }

    const sources = [];
    if (entry.woff2) sources.push(`url("../fonts/${entry.woff2}") format("woff2")`);
    if (entry.woff) sources.push(`url("../fonts/${entry.woff}") format("woff")`);
    if (sources.length === 0) continue;

    out += `@font-face {
  font-family: "${fontFamily}";
  src: ${sources.join(", ")};
  font-weight: ${fontWeight};
  font-style: ${fontStyle};
  font-display: swap;
}\n\n`;
  }
  writeIfChanged(paths.fonts.scssOut, out);
  done();
}

export const fonts = gulp.series(convertOtfToTtf, convertTtfToWebFonts, generateFontsScss, (done) => { try { browserSync.reload(); } catch (e) {} ; done(); });

// ------------------ Clean ------------------
export async function cleanOut() {
  await deleteAsync([`${OUT}/**`, `!${OUT}`], { force: true });
}
export async function cleanAll() {
  await deleteAsync(["dist/**", "build/**"], { force: true });
}

// ------------------ PATH FIXER ------------------
function resolvePath(url) {
  if (!url || url.startsWith("http") || url.startsWith("//") || url.startsWith("#") || url.startsWith("data:")) return url;
  let clean = url.replace(/^(\.\.\/|\.\/)*src\//, "").replace(/^(\.\.\/|\.\/)+/, "");
  
  if (clean.includes("components/")) {
    let parts = clean.split(/\/|\\/);
    let newParts = parts.filter(p => p !== "components" && p !== "common" && p !== "images");
    return "images/" + newParts.join("/");
  }
  if (clean.includes("public/images/")) {
    return clean.replace("public/images/", "images/public/images/");
  }
  return url;
}

function fixPathsStream() {
  return replace(/(src|href|srcset|url)\s*(=|\()\s*["']?([^"'\)]+)["']?\)?/gi, (match, attr, sep, url) => {
    if (attr.toLowerCase() === 'url') {
      const fixed = resolvePath(url);
      return `url("${fixed}")`;
    }
    const fixed = resolvePath(url);
    const q = match.includes("'") ? "'" : '"';
    return `${attr}=${q}${fixed}${q}`;
  });
}

// ------------------ HTML (Updated with Version Number) ------------------
const versionConfig = {
  'value': '%DT%',
  'append': {
    'key': 'v',
    'to': ['css', 'js'],
  },
};

export function htmlDev() {
  return gulp.src(paths.html.src)
    .pipe(plumber())
    .pipe(fileInclude({ prefix: "@@", basepath: "@file" }))
    .pipe(fixPathsStream())
    .pipe(gulp.dest(paths.html.dest()))
    .on("end", () => { try { browserSync.reload(); } catch (e) {} });
}

export function htmlProd() {
  return gulp.src(paths.html.src)
    .pipe(plumber())
    .pipe(fileInclude({ prefix: "@@", basepath: "@file" }))
    .pipe(fixPathsStream())
    .pipe(replace('./js/main.js', './js/main.min.js'))
    .pipe(htmlmin({ collapseWhitespace: true, removeComments: true }))
    .pipe(versionNumber(versionConfig)) // Cache Busting
    .pipe(gulp.dest(paths.html.dest()))
    .on("end", () => { try { browserSync.reload(); } catch (e) {} });
}

// ------------------ Images (Back to SRC + Dist) ------------------

export function imagesPublicFavicons() {
  return gulp.src(paths.images.publicFaviconsSrc, { allowEmpty: true, encoding: false })
    .pipe(plumber())
    .pipe(newer(path.join(paths.images.dest(), "public/favicons/")))
    .pipe(gulp.dest(path.join(paths.images.dest(), "public/favicons/")))
    .on("end", () => { try { browserSync.reload(); } catch (e) {} });
}

export function imagesPublicImages() {
  return gulp.src(paths.images.publicImagesSrc, { allowEmpty: true, encoding: false })
    .pipe(plumber())
    .pipe(newer(path.join(paths.images.dest(), "public/images/")))
    .pipe(imagemin())
    .pipe(gulp.dest(path.join(paths.images.dest(), "public/images/")))
    .on("end", () => { try { browserSync.reload(); } catch (e) {} });
}

// UPDATED: Generates WebP back to src/public/images AND dist
export function imagesWebpPublicImages() {
  return gulp.src(paths.images.publicImagesWebpSrc, { allowEmpty: true, encoding: false })
    .pipe(plumber())
    // 1. Check if webp exists in SRC
    .pipe(newer({ dest: "src/public/images", ext: '.webp' }))
    .pipe(webp())
    // 2. Save back to SRC
    .pipe(gulp.dest("src/public/images"))
    // 3. Save to DIST
    .pipe(gulp.dest(path.join(paths.images.dest(), "public/images/")))
    .on("end", () => { try { browserSync.reload(); } catch (e) {} });
}

export function imagesComponents() {
  return gulp.src(paths.images.componentsSrc, { allowEmpty: true, base: "src/components", encoding: false })
    .pipe(plumber())
    .pipe(rename(function (filePath) {
      let parts = filePath.dirname.split(/\/|\\/);
      let newParts = parts.filter(part => part !== "common" && part !== "images");
      filePath.dirname = newParts.join("/");
    }))
    .pipe(newer(paths.images.dest()))
    .pipe(imagemin())
    .pipe(gulp.dest(paths.images.dest()))
    .on("end", () => { try { browserSync.reload(); } catch (e) {} });
}

// UPDATED: Generates WebP back to src/components/... AND dist
export function imagesWebpComponents() {
  return gulp.src(paths.images.componentsWebpSrc, { allowEmpty: true, base: "src/components", encoding: false })
    .pipe(plumber())
    // 1. Check if webp exists in SRC (next to original)
    .pipe(newer({ dest: "src/components", ext: '.webp' }))
    .pipe(webp())
    // 2. Save back to SRC (maintaining relative structure thanks to base: src/components)
    .pipe(gulp.dest("src/components"))
    // 3. Rename (flatten paths) for DIST
    .pipe(rename(function (filePath) {
      let parts = filePath.dirname.split(/\/|\\/);
      let newParts = parts.filter(part => part !== "common" && part !== "images");
      filePath.dirname = newParts.join("/");
    }))
    // 4. Save to DIST
    .pipe(gulp.dest(paths.images.dest()))
    .on("end", () => { try { browserSync.reload(); } catch (e) {} });
}

export const images = gulp.parallel(imagesPublicFavicons, imagesPublicImages, imagesWebpPublicImages, imagesComponents, imagesWebpComponents);

// ------------------ Scripts (Updated with Esbuild) ------------------
export function scriptsDev() {
  return gulp.src(paths.scripts.src, { allowEmpty: true })
    .pipe(plumber())
    .pipe(gulpEsbuild({
      outfile: 'main.js',
      bundle: true,
      sourcemap: true,
      minify: false,
      platform: 'browser',
    }))
    .pipe(gulp.dest(paths.scripts.dest()))
    .on("end", () => { try { browserSync.reload(); } catch (e) {} });
}

export function scriptsProd() {
  return gulp.src(paths.scripts.src, { allowEmpty: true })
    .pipe(plumber())
    .pipe(gulpEsbuild({
      outfile: 'main.min.js', // Output as .min.js
      bundle: true,
      sourcemap: false,
      minify: true, // Minify enabled
      platform: 'browser',
    }))
    .pipe(gulp.dest(paths.scripts.dest()))
    .on("end", () => { try { browserSync.reload(); } catch (e) {} });
}

// ------------------ Styles ------------------
export function stylesDev() {
  return gulp.src(paths.styles.src, { allowEmpty: true })
    .pipe(plumber())
    .pipe(sourcemaps.init())
    .pipe(sass({ quietDeps: true }).on("error", sass.logError))
    .pipe(autoprefixer())
    .pipe(fixPathsStream())
    .pipe(sourcemaps.write('.'))
    .pipe(gulp.dest(paths.styles.dest()))
    .pipe(browserSync.stream({ match: "**/*.css" }));
}

export function stylesProd() {
  return gulp.src(paths.styles.src, { allowEmpty: true })
    .pipe(plumber())
    .pipe(sass({ quietDeps: true }).on("error", sass.logError))
    .pipe(autoprefixer())
    .pipe(fixPathsStream())
    .pipe(cleanCSS({ level: 2 }))
    .pipe(gulp.dest(paths.styles.dest()))
    .pipe(browserSync.stream({ match: "**/*.css" }));
}

// ------------------ Build Tasks ------------------
export const buildCoreDev = gulp.series(cleanOut, generateComponentsAuto, fonts, gulp.parallel(htmlDev, stylesDev, scriptsDev, images));
export const buildCoreProd = gulp.series(cleanOut, generateComponentsAuto, fonts, gulp.parallel(htmlProd, stylesProd, scriptsProd, images));

function setOut(target) {
  return function setOutTask(done) { OUT = target; console.log("Output:", OUT); return done(); };
}

export const build = gulp.series(setOut("build"), buildCoreProd);
export const dev = gulp.series(setOut("dist"), buildCoreDev, serve);

// ------------------ Watcher ------------------
export function serve(done) {
  browserSync.init({
    server: { baseDir: `./${OUT}` },
    port: 3000,
    open: true, // FIXED: Opens browser automatically
    notify: false, 
    ui: false
  });

  gulp.watch(["src/*.html", "src/components/**/*.html"], gulp.series(htmlDev));
  gulp.watch(["src/scss/**/*.scss", "!src/scss/_components-auto.scss", "!src/scss/_fonts.scss"], gulp.series(generateComponentsAuto, stylesDev));
  gulp.watch(["src/components/**/*.scss"], gulp.series(generateComponentsAuto, stylesDev));
  
  // Watch all JS, but trigger scriptsDev (which only rebuilds entry point)
  gulp.watch([paths.scripts.watch], gulp.series(scriptsDev));
  
  gulp.watch([paths.images.publicFaviconsSrc, paths.images.publicImagesSrc, paths.images.componentsSrc], gulp.series(images));
  gulp.watch(["src/fonts/*.{ttf,otf}"], gulp.series(fonts));
  done();
}

export default dev;
GULP

echo "Gulpfile saved."

# =====================================================================
# Source Files
# =====================================================================

echo
echo "Creating source structure (HTML, SCSS, JS)..."

# HEADER
cat > src/components/common/Header/Header.html <<'EOF'
<header class="header">
	<div class="container">
		<p>Header</p>
	</div>
</header>
EOF

cat > src/components/common/Header/_Header.scss <<'EOF'
.header {}
EOF

cat > src/components/common/Header/_HeaderResponsive.scss <<'EOF'
@media (max-width: 768px) {}
EOF

# FOOTER
cat > src/components/common/Footer/Footer.html <<'EOF'
<footer class="footer">
	<div class="container">
		<p>Footer</p>
	</div>
</footer>
EOF

cat > src/components/common/Footer/_Footer.scss <<'EOF'
.footer {}
EOF

cat > src/components/common/Footer/_FooterResponsive.scss <<'EOF'
@media (max-width: 768px) {}
EOF

# HERO
cat > src/components/Home/Hero/Hero.html <<'EOF'
<section class="hero">
	<div class="container">
		<p>Section Hero</p>
	</div>
</section>
EOF

cat > src/components/Home/Hero/_Hero.scss <<'EOF'
.hero {}
EOF

cat > src/components/Home/Hero/_HeroResponsive.scss <<'EOF'
@media (max-width: 768px) {}
EOF

# Home wrapper & index
cat > src/components/Home/Home.html <<'EOF'
@@include("./Hero/Hero.html")
EOF

# FIXED: Added .wrapper around the content
cat > src/index.html <<'HTML'
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Project Name</title>
	<link rel="icon" type="image/svg+xml" href="./images/public/favicons/favicon.svg">
	<link rel="apple-touch-icon" href="./images/public/favicons/apple-touch-icon.png">
  <link rel="stylesheet" href="./css/main.css" />
</head>
<body>
  <div class="wrapper">
    @@include("./components/common/Header/Header.html")
    <main>
      @@include("./components/Home/Home.html")
    </main>
    @@include("./components/common/Footer/Footer.html")
  </div>
  <script src="./js/main.js"></script>
</body>
</html>
HTML

# SCSS files
cat > src/scss/_reset.scss <<'EOF'
* {
	padding: 0px;
	margin: 0px;
	border: none;
}

*,
*::before,
*::after {
	box-sizing: border-box;
}

a, a:link, a:visited {
  text-decoration: none;
}

a:hover {
  text-decoration: none;
}

aside, nav, footer, header, section, main {
	display: block;
}

h1, h2, h3, h4, h5, h6, p {
  font-size: inherit;
	font-weight: inherit;
}

ul, ul li {
	list-style: none;
}

img {
	vertical-align: top;
}

img, svg {
	max-width: 100%;
	height: auto;
}

address {
  font-style: normal;
}

input, textarea, button, select {
	font-family: inherit;
  font-size: inherit;
  color: inherit;
  background-color: transparent;
}

input::-ms-clear {
	display: none;
}

button, input[type="submit"] {
  display: inline-block;
  box-shadow: none;
  background-color: transparent;
  background: none;
  cursor: pointer;
}

input:focus, input:active,
button:focus, button:active {
  outline: none;
}

button::-moz-focus-inner {
	padding: 0;
	border: 0;
}

label {
	cursor: pointer;
}

legend {
	display: block;
}

input[type='file'] {
	max-width: 100%;
}
EOF

# FIXED: Added .wrapper and main styles for sticky footer
cat > src/scss/_base.scss <<'EOF'
:root {
	--font-family: "", sans-serif;

	--max-width: 1440px;
	--padding: 0 20px;
	--margin: 0 auto;
	
	--text-color: #000;
	--accent: #C76904;
	--background-color: #FFFFFF;
}

html {
	scroll-behavior: smooth;
    height: 100%;
}

body {
	font-family: var(--font-family);
	font-weight: 400;
	font-size: 18px;
	height: 100%;
  display: flex;
  flex-direction: column;
	color: var(--text-color);
	background-color: var(--background-color);
}

.container {
	max-width: var(--max-width);
	padding: var(--padding);
	margin: var(--margin)
}

.wrapper {
  min-height: 100%;
  display: flex;
  flex-direction: column; 
}

main {
  flex: 1 1 auto;
}

.footer {
	margin-top: auto;
}
EOF

cat > src/scss/main.scss <<'EOF'
@use "./_reset";
@use "./_base";
@use "./_fonts";
@use "./_components-auto";
EOF

# placeholders
echo "// Auto-generated imports" > src/scss/_components-auto.scss
echo "// Auto-generated fonts" > src/scss/_fonts.scss

# JS (Updated for module support)
cat > src/scripts/main.js <<'EOF'
// Entry point for Esbuild
// You can import modules here: import { something } from "./module.js";

console.log("main.js loaded via Esbuild");

const testModern = () => {
  console.log("Arrow functions work!");
};
testModern();
EOF

# README
cat > README.md <<'EOF'
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
EOF

echo "Files created."

# =====================================================================
# Final package.json
# =====================================================================

cat > package.json <<EOF
{
  "name": "${PROJECT_NAME}",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "gulp dev",
    "build": "gulp build",
    "clean": "gulp cleanAll",
    "update": "npx npm-check-updates -u && npm install"
  },
  "devDependencies": {}
}
EOF

echo
echo "Installing npm devDependencies (this may take a minute)..."
npm install --save-dev \
  gulp \
  gulp-sass \
  sass \
  gulp-file-include \
  gulp-imagemin \
  gulp-webp \
  gulp-rename \
  gulp-terser \
  gulp-autoprefixer \
  gulp-plumber \
  browser-sync \
  gulp-fonter \
  gulp-ttf2woff \
  gulp-ttf2woff2 \
  del \
  merge-stream \
  npm-check-updates \
  chokidar \
  through2 \
  gulp-sourcemaps \
  gulp-clean-css \
  gulp-htmlmin \
  gulp-replace \
  gulp-newer \
  gulp-esbuild \
  gulp-version-number

echo
echo "==============================================="
echo "Initialization complete!"
echo "Author: Andrey Lo (https://www.loitweb.com/)"
echo "My GitHub (https://github.com/LoITWeb)"
echo "==============================================="

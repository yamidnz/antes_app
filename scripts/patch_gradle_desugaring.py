#!/usr/bin/env python3
"""
Habilita "core library desugaring" en android/app/build.gradle(.kts),
requerido por flutter_local_notifications independientemente de si se usan
notificaciones programadas o no.

Soporta tanto el Gradle clásico (build.gradle, sintaxis Groovy) como el
Gradle moderno (build.gradle.kts, sintaxis Kotlin DSL), porque `flutter
create` cambia el formato por defecto según la versión del SDK usada en
el runner de CI, y no queremos que un cambio de versión de Flutter rompa
la compilación en silencio.
"""
import re
import sys
from pathlib import Path

KTS_PATH = Path('android/app/build.gradle.kts')
GROOVY_PATH = Path('android/app/build.gradle')

if KTS_PATH.exists():
    path = KTS_PATH
    is_kts = True
elif GROOVY_PATH.exists():
    path = GROOVY_PATH
    is_kts = False
else:
    print('No se encontró android/app/build.gradle(.kts) — ¿corrió "flutter create" antes que este script?')
    sys.exit(1)

content = path.read_text(encoding='utf-8')

if 'coreLibraryDesugaring' in content:
    print(f'{path} ya tiene core library desugaring configurado, no se toca.')
    sys.exit(0)

# --- 1. compileOptions: agregar el flag de desugaring ---
compile_options_re = re.compile(r'(compileOptions\s*\{)')
if compile_options_re.search(content):
    if is_kts:
        injection = r'\1\n        isCoreLibraryDesugaringEnabled = true'
    else:
        injection = r'\1\n        coreLibraryDesugaringEnabled true'
    content = compile_options_re.sub(injection, content, count=1)
else:
    # No había bloque compileOptions: creamos uno dentro de `android { ... }`.
    android_block_re = re.compile(r'(android\s*\{)')
    if is_kts:
        block = (
            '\\1\n'
            '    compileOptions {\n'
            '        isCoreLibraryDesugaringEnabled = true\n'
            '        sourceCompatibility = JavaVersion.VERSION_11\n'
            '        targetCompatibility = JavaVersion.VERSION_11\n'
            '    }'
        )
    else:
        block = (
            '\\1\n'
            '    compileOptions {\n'
            '        coreLibraryDesugaringEnabled true\n'
            '        sourceCompatibility JavaVersion.VERSION_11\n'
            '        targetCompatibility JavaVersion.VERSION_11\n'
            '    }'
        )
    content = android_block_re.sub(block, content, count=1)

# --- 2. dependencies: agregar la librería de desugaring ---
dep_line = (
    '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
    if is_kts else
    "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
)

dependencies_re = re.compile(r'(dependencies\s*\{)')
matches = list(dependencies_re.finditer(content))
if matches:
    # Usamos el último bloque `dependencies {` del archivo: en
    # android/app/build.gradle(.kts) suele haber uno solo (el del módulo
    # app), pero por si acaso tomamos el último para evitar bloques
    # `buildscript { dependencies { ... } }` si los hubiera.
    last = matches[-1]
    insert_at = last.end()
    content = content[:insert_at] + '\n' + dep_line + '\n' + content[insert_at:]
else:
    # No había bloque dependencies: lo agregamos al final del archivo.
    content += f'\n\ndependencies {{\n{dep_line}\n}}\n'

path.write_text(content, encoding='utf-8')
print(f'{path}: core library desugaring habilitado ({"Kotlin DSL" if is_kts else "Groovy"}).')

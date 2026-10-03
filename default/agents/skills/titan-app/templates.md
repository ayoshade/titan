# titan-app templates

Copy these files into a new directory, then replace the placeholders
everywhere, file names included:

| Placeholder | Meaning | Example |
| --- | --- | --- |
| `myapp` | Binary, package and directory name (lowercase, `[a-z0-9-]`) | `hype` |
| `My App` | Human-readable name | `Hype` |
| `io.titan.myapp` | Wayland app id and `.desktop` basename (`io.titan.` + binary name) | `io.titan.hype` |
| `One-line description` | Used in the `.desktop` file and the PKGBUILD | `Quick notes` |

```text
myapp/
├── myapp.pro              qmake project: one binary, QML compiled into resources
├── src/
│   ├── main.cpp           app id, theme singleton, engine
│   ├── TitanTheme.h       live Titan theme (palette, accent, fonts, radii, motion)
│   └── TitanTheme.cpp
├── qml/
│   ├── Main.qml           window and example UI
│   ├── TitanButton.qml    small themed components (extend as needed)
│   └── TitanCard.qml
├── resources.qrc          bundles qml/ and the icon into the binary
├── io.titan.myapp.desktop launcher entry
├── io.titan.myapp.svg     scalable app icon
└── packaging/
    └── PKGBUILD           Arch package: /usr/bin, .desktop, icon
```

These templates were built and run on Titan with Qt 6.11.2 (`qmake6`, `make`,
GCC). See the verification notes in [SKILL.md](SKILL.md).

## myapp.pro

```qmake
TEMPLATE = app
TARGET = myapp
QT += quick quickcontrols2
CONFIG += c++20 release

SOURCES += src/main.cpp src/TitanTheme.cpp
HEADERS += src/TitanTheme.h
RESOURCES += resources.qrc

# `make install` (used by the PKGBUILD) places the binary, launcher entry and icon.
target.path = /usr/bin
desktop.files = $$PWD/io.titan.myapp.desktop
desktop.path = /usr/share/applications
icon.files = $$PWD/io.titan.myapp.svg
icon.path = /usr/share/icons/hicolor/scalable/apps
INSTALLS += target desktop icon
```

## resources.qrc

```xml
<!DOCTYPE RCC>
<RCC version="1.0">
  <qresource prefix="/">
    <file>qml/Main.qml</file>
    <file>qml/TitanButton.qml</file>
    <file>qml/TitanCard.qml</file>
    <file>io.titan.myapp.svg</file>
  </qresource>
</RCC>
```

## src/main.cpp

```cpp
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QtQml>
#include "TitanTheme.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("myapp");
    app.setApplicationDisplayName("My App");
    // The Wayland app id must match the .desktop basename so Hyprland rules,
    // the launcher and the shell all identify the window as this app.
    app.setDesktopFileName("io.titan.myapp");
    app.setWindowIcon(QIcon(":/io.titan.myapp.svg"));
    QQuickStyle::setStyle("Basic");   // fully restyled by our own components

    TitanTheme theme;
    qmlRegisterSingletonInstance("Titan", 1, 0, "Titan", &theme);

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.load(QUrl("qrc:/qml/Main.qml"));
    return app.exec();
}
```

## src/TitanTheme.h

```cpp
#pragma once
#include <QColor>
#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QStringList>
#include <QTimer>

// Live view of the Titan theme. Reads the same files the Titan shell uses and
// re-reads them whenever they change, so the app follows theme, accent, font,
// radius and motion changes without a restart. Missing files fall back to the
// Graphite palette, so the app still runs outside Titan.
class TitanTheme : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString themeId READ themeId NOTIFY changed)
    Q_PROPERTY(QColor background READ background NOTIFY changed)
    Q_PROPERTY(QColor shell READ shell NOTIFY changed)
    Q_PROPERTY(QColor surface READ surface NOTIFY changed)
    Q_PROPERTY(QColor raised READ raised NOTIFY changed)
    Q_PROPERTY(QColor border READ border NOTIFY changed)
    Q_PROPERTY(QColor text READ text NOTIFY changed)
    Q_PROPERTY(QColor muted READ muted NOTIFY changed)
    Q_PROPERTY(QColor accent READ accent NOTIFY changed)
    Q_PROPERTY(QColor danger READ danger NOTIFY changed)
    Q_PROPERTY(QColor notch READ notch NOTIFY changed)
    Q_PROPERTY(QStringList swatches READ swatches NOTIFY changed)
    Q_PROPERTY(QString fontFamily READ fontFamily NOTIFY changed)
    Q_PROPERTY(QString displayFont READ displayFont NOTIFY changed)
    Q_PROPERTY(int fontSize READ fontSize NOTIFY changed)
    Q_PROPERTY(int radius READ radius NOTIFY changed)
    Q_PROPERTY(int panelRadius READ panelRadius NOTIFY changed)
    Q_PROPERTY(bool reduceMotion READ reduceMotion NOTIFY changed)
    Q_PROPERTY(int duration READ duration NOTIFY changed)
    Q_PROPERTY(int movement READ movement NOTIFY changed)

public:
    explicit TitanTheme(QObject *parent = nullptr);

    QString themeId() const { return m_themeId; }
    QColor background() const { return color("background", "#080a0d"); }
    QColor shell() const { return color("shell", "#080a0d"); }
    QColor surface() const { return color("surface", "#121417"); }
    QColor raised() const { return color("raised", "#202328"); }
    QColor border() const { return color("border", "#202328"); }
    QColor text() const { return color("text", "#e1e5e9"); }
    QColor muted() const { return color("muted", "#9299a3"); }
    QColor danger() const { return color("danger", "#bd8585"); }
    QColor notch() const { return color("notch", "#000000"); }
    QColor accent() const;
    QStringList swatches() const;
    QString fontFamily() const { return setting("bodyFont", "Inter").toString(); }
    QString displayFont() const { return setting("displayFont", fontFamily()).toString(); }
    int fontSize() const { return setting("fontSize", 12).toInt(); }
    int radius() const { return setting("cornerRadius", 16).toInt(); }
    int panelRadius() const { return setting("panelRadius", 26).toInt(); }
    bool reduceMotion() const { return !m_motion || setting("reduceMotion", false).toBool(); }
    int duration() const { return reduceMotion() ? 0 : setting("fadeMs", 200).toInt(); }
    int movement() const { return reduceMotion() ? 0 : setting("movementMs", 330).toInt(); }

signals:
    void changed();

private:
    void reload();
    void rewatch();
    QColor color(const char *key, const char *fallback) const;
    QJsonValue setting(const char *key, const QJsonValue &fallback) const;

    QString m_themeDir, m_preferencesPath, m_settingsPath;
    QString m_themeId, m_accentName;
    bool m_motion = true;
    QJsonObject m_palette, m_settings;
    QByteArray m_signature;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
```

## src/TitanTheme.cpp

```cpp
#include "TitanTheme.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QStandardPaths>

static QJsonDocument readJson(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll());
}

static QString envOr(const char *name, const QString &fallback)
{
    const QString value = qEnvironmentVariable(name);
    return value.isEmpty() ? fallback : value;
}

TitanTheme::TitanTheme(QObject *parent) : QObject(parent)
{
    const QString home = QDir::homePath();
    // Same locations as the Titan shell: the palette catalog and defaults ship
    // with Titan; the user's choices live in ~/.config/titan.
    const QString config = envOr("XDG_CONFIG_HOME", home + "/.config");
    m_themeDir = config + "/quickshell/umbra/theme";
    m_preferencesPath = config + "/titan/preferences.json";
    m_settingsPath = config + "/titan/settings.json";

    // Titan writes these files atomically (rename into place), which drops a
    // plain file watch, so the directories are watched too and the paths are
    // re-added after every change. Bursts are coalesced.
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(120);
    connect(&m_debounce, &QTimer::timeout, this, &TitanTheme::reload);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, &m_debounce, qOverload<>(&QTimer::start));
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, &m_debounce, qOverload<>(&QTimer::start));
    reload();
}

void TitanTheme::rewatch()
{
    const QStringList wanted = {
        m_themeDir, m_themeDir + "/palettes.json",
        QFileInfo(m_preferencesPath).absolutePath(), m_preferencesPath, m_settingsPath,
    };
    for (const QString &path : wanted)
        if (QFileInfo::exists(path) && !m_watcher.files().contains(path) && !m_watcher.directories().contains(path))
            m_watcher.addPath(path);
}

void TitanTheme::reload()
{
    // Defaults first, then the user's choices on top.
    QJsonObject prefs = readJson(m_themeDir + "/preferences-default.json").object();
    const QJsonObject user = readJson(m_preferencesPath).object();
    for (auto it = user.begin(); it != user.end(); ++it)
        prefs.insert(it.key(), it.value());
    const QJsonArray palettes = readJson(m_themeDir + "/palettes.json").array();
    m_themeId = prefs.value("theme").toString("graphite");
    m_accentName = prefs.value("accent").toString("theme");
    m_motion = prefs.value("motion").toBool(true);
    m_palette = {};
    for (const QJsonValue &p : palettes)
        if (p.toObject().value("id").toString() == m_themeId) { m_palette = p.toObject(); break; }
    m_settings = readJson(m_settingsPath).object();
    rewatch();

    // Emit only when something visible changed; the shell rewrites files often.
    QByteArray signature = QJsonDocument(m_palette).toJson(QJsonDocument::Compact)
        + QJsonDocument(m_settings).toJson(QJsonDocument::Compact) + m_accentName.toUtf8()
        + (m_motion ? "1" : "0");
    if (signature != m_signature) {
        m_signature = signature;
        emit changed();
    }
}

QColor TitanTheme::color(const char *key, const char *fallback) const
{
    const QColor c(m_palette.value(key).toString());
    return c.isValid() ? c : QColor(fallback);
}

QJsonValue TitanTheme::setting(const char *key, const QJsonValue &fallback) const
{
    const QJsonValue v = m_settings.value(key);
    return v.isUndefined() || v.isNull() ? fallback : v;
}

QColor TitanTheme::accent() const
{
    // Mirrors the shell's Theme.accent: palette accent, a fixed accent, or custom.
    if (m_accentName == "custom") {
        const QColor custom(setting("accentCustom", QString()).toString());
        if (custom.isValid()) return custom;
    }
    if (m_accentName == "ice") return QColor("#8faebc");
    if (m_accentName == "sage") return QColor("#9fae9d");
    if (m_accentName == "silver") return QColor("#aeb8c4");
    return color("accent", "#aeb8c4");
}

QStringList TitanTheme::swatches() const
{
    QStringList out;
    for (const QJsonValue &v : m_palette.value("swatches").toArray())
        out << v.toString();
    return out;
}
```

## qml/Main.qml

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Titan

ApplicationWindow {
    id: window
    width: 720; height: 480
    minimumWidth: 420; minimumHeight: 300
    visible: true
    title: "My App"
    color: Titan.shell
    font.family: Titan.fontFamily
    font.pixelSize: Titan.fontSize
    Behavior on color { ColorAnimation { duration: Titan.duration } }

    ColumnLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "My App"
                color: Titan.text
                font { family: Titan.displayFont; pixelSize: Titan.fontSize + 8; weight: Font.DemiBold }
                Layout.fillWidth: true
            }
            Label { text: Titan.themeId; color: Titan.muted; font.pixelSize: Titan.fontSize - 1 }
        }

        TitanCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 10
                Label { text: "Follows the Titan theme live"; color: Titan.text; font.weight: Font.DemiBold }
                Label {
                    text: "Change the theme, accent, font or corner radius and this window updates without a restart."
                    color: Titan.muted; wrapMode: Text.Wrap; Layout.fillWidth: true
                }
                Row {
                    spacing: 6
                    Repeater {
                        model: Titan.swatches
                        Rectangle { required property string modelData; width: 14; height: 14; radius: 7; color: modelData }
                    }
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    spacing: 8
                    TitanButton { text: "Primary"; primary: true; onClicked: status.text = "Primary clicked" }
                    TitanButton { text: "Secondary"; onClicked: status.text = "Secondary clicked" }
                    Label { id: status; color: Titan.muted; Layout.leftMargin: 8 }
                }
            }
        }
    }
}
```

## qml/TitanCard.qml

```qml
import QtQuick
import Titan

// Graphite surface used for grouped content, like the shell's cards.
Rectangle {
    radius: Titan.panelRadius
    color: Titan.surface
    Behavior on color { ColorAnimation { duration: Titan.duration } }
}
```

## qml/TitanButton.qml

```qml
import QtQuick
import QtQuick.Controls
import Titan

// Pill button: accent fill when primary, subtle graphite otherwise.
Button {
    id: control
    property bool primary: false
    implicitHeight: 34
    leftPadding: 18; rightPadding: 18
    font.family: Titan.fontFamily
    font.pixelSize: Titan.fontSize
    font.weight: Font.DemiBold
    contentItem: Text {
        text: control.text; font: control.font
        color: control.primary ? Titan.notch : Titan.text
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: height / 2
        color: control.primary ? (control.down ? Qt.darker(Titan.accent, 1.15) : Titan.accent)
                               : (control.hovered ? Titan.raised : Qt.alpha(Titan.text, 0.06))
        border.width: control.activeFocus ? 2 : 0
        border.color: Qt.alpha(Titan.accent, 0.6)
        Behavior on color { ColorAnimation { duration: Titan.duration } }
    }
    Accessible.name: text
}
```

## io.titan.myapp.desktop

```ini
[Desktop Entry]
Type=Application
Name=My App
Comment=One-line description
Exec=myapp
Icon=io.titan.myapp
Terminal=false
Categories=Utility;
StartupWMClass=io.titan.myapp
```

## io.titan.myapp.svg

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="4" y="4" width="56" height="56" rx="16" fill="#000000"/>
  <rect x="18" y="27" width="28" height="10" rx="5" fill="#aeb8c4"/>
</svg>
```

Replace this with an original icon for the app. Keep it simple, readable at
24 px, and in the black/graphite language.

## packaging/PKGBUILD

The PKGBUILD lives in `packaging/`, not the project root. `makepkg` uses
`src/` and `pkg/` beside the PKGBUILD as its own work directories, and
`makepkg -C` deletes `src/`, which at the root would be the app's code.

```bash
# Maintainer: Your Name <you@example.com>
pkgname=myapp
pkgver=0.1.0
pkgrel=1
pkgdesc="One-line description"
arch=('x86_64')
license=('MIT')
depends=('qt6-base' 'qt6-declarative')
makedepends=('gcc' 'make')
# Built from the project directory one level up; nothing is downloaded.
source=()

build() {
  mkdir -p "$srcdir/build"
  cd "$srcdir/build"
  qmake6 "$startdir/../myapp.pro"
  make -j"$(nproc)"
}

package() {
  cd "$srcdir/build"
  make INSTALL_ROOT="$pkgdir" install
}
```

Add every runtime library the app links or imports to `depends` (for example
`qt6-multimedia`, `qt6-svg`). `qt6-base` provides `qmake6`. Ignore build
output in Git with `packaging/src/`, `packaging/pkg/`, `packaging/*.pkg.tar.*`,
`build/`, `*.o`, `moc_*`, `qrc_*` and `Makefile`.

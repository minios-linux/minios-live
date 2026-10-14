#!/usr/bin/python3
"""Exercise desktop installers in a path-remapped fixture, without APT or root.

Only absolute target paths and package/service commands are substituted. The
actual installers generate their configs, which are parsed and checked below.
CondinAPT filter tests use its real parser with repository availability mocked.
"""
import configparser
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "linux-live/scripts"
COMMON = ROOT / "linux-live/minioslib"
VARIANTS = ("minimum", "standard", "toolbox", "ultra")
DESKTOPS = ("gnome", "cinnamon", "lxqt")


def ini(path):
    config = configparser.ConfigParser(strict=False, interpolation=None)
    config.optionxform = str
    config.read(path)
    return config


class DesktopModuleTests(unittest.TestCase):
    def build_fixture(self, directory, desktop, variant, distribution, merged_menu_alias=False):
        target = Path(directory)
        module = SCRIPTS / f"04-{desktop}-desktop"
        for source in (SCRIPTS / "03-gui-base/rootcopy-install", module / "rootcopy-install"):
            shutil.copytree(source, target, dirs_exist_ok=True)

        def remap(text):
            for prefix in ("/etc/", "/usr/", "/var/"):
                text = text.replace(prefix, f"{target}{prefix}")
            for filename in ("/minioslib", "/minios_build.conf", "/condinapt"):
                text = text.replace(filename, f"{target}{filename}")
            return text

        (target / "install").write_text(remap((module / "install").read_text()))
        (target / "minios_build.conf").write_text("")
        (target / "minioslib").write_text(remap(COMMON.read_text()) + '''
console_colors() { :; }
pkg_is_installed() { [ "$1" = lightdm ] && [ "$MOCK_LIGHTDM" = yes ]; }
''')
        (target / "condinapt").write_text("#!/bin/sh\nexit 0\n")
        (target / "condinapt").chmod(0o755)
        for relative in ("etc/apt/apt.conf.d", "usr/share/backgrounds", "etc/gdm3",
                         "usr/share/themes/Greybird-MiniOS", "usr/share/themes/Greybird-MiniOS-dark",
                         "usr/share/icons/elementary-minios-dark", "usr/share/minios", "mock-bin"):
            (target / relative).mkdir(parents=True, exist_ok=True)
        for edition in VARIANTS:
            (target / f"usr/share/backgrounds/minios6-{edition}.jpg").touch()
        (target / "usr/share/minios/minios6-background.png").touch()
        (target / "etc/gdm3/daemon.conf").write_text("[daemon]\n")
        for name in ("cinnamon-session", "startlxqt"):
            binary = target / "usr/bin" / name
            binary.write_text("#!/bin/sh\nexit 0\n")
            binary.chmod(0o755)
        openbox = target / "etc/xdg/openbox/rc.xml"
        openbox.parent.mkdir(parents=True, exist_ok=True)
        openbox.write_text('''<openbox_config xmlns="http://openbox.org/3.4/rc">
<theme><name>Clearlooks</name><titleLayout>NLIMC</titleLayout><animateIconify>yes</animateIconify>
<font place="ActiveWindow"><name>Sans</name><size>10</size></font></theme>
<desktops><number>4</number></desktops>
<keyboard><keybind key="A-Tab"><action name="NextWindow"/></keybind></keyboard>
<mouse><context name="Frame"><mousebind button="A-Left" action="Drag"><action name="Move"/></mousebind></context></mouse>
</openbox_config>''')
        applets = target / "usr/share/cinnamon/applets"
        (applets / "menu@cinnamon.org").mkdir(parents=True)
        for name in ("grouped-window-list", "xapp-status"):
            (applets / f"{name}@cinnamon.org").mkdir()
        (applets / "menu@cinnamon.org/settings-schema.json").write_text(json.dumps({
            "menu-custom": {"default": False}, "menu-icon": {"default": "cinnamon-symbolic"},
            "menu-label": {"default": "Menu"}, "show-recents": {"default": True},
            "search-filesystem": {"default": True}, "untouched": {"default": 42}}))
        for command in ("update-alternatives", "debconf-set-selections", "dconf", "locale-gen", "glib-compile-schemas"):
            stub = target / "mock-bin" / command
            # debconf is a pipe consumer; exiting before reading can SIGPIPE
            # the installer's printf under pipefail, unlike the real command.
            stub.write_text("#!/bin/sh\nwhile IFS= read -r line; do :; done\n" if command == "debconf-set-selections" else "#!/bin/sh\nexit 0\n")
            stub.chmod(0o755)
        stub = target / "mock-bin/dpkg-query"
        stub.write_text("#!/bin/sh\nexit 1\n")
        stub.chmod(0o755)
        if merged_menu_alias:
            menus = target / "etc/xdg/menus"
            (menus / "applications-merged").mkdir(parents=True, exist_ok=True)
            (menus / f"{desktop}-applications-merged").symlink_to("applications-merged", target_is_directory=True)
        env = dict(os.environ, PATH=f"{target}/mock-bin:{os.environ['PATH']}",
                   PACKAGE_VARIANT=variant, DISTRIBUTION=distribution,
                   DISTRIBUTION_PROFILE="debian", INIT_SYSTEM="sysvinit" if distribution == "excalibur" else "systemd",
                   LOCALE="ru_RU", LAYOUTID="ru", MULTILINGUAL="false", KEEP_LOCALES="false",
                   MOCK_LIGHTDM="yes" if desktop != "gnome" or distribution == "excalibur" else "no")
        result = subprocess.run(["bash", str(target / "install")], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((target / "etc/apt/apt.conf.d/99minios-desktop-build").exists())
        self.assertFalse((target / "usr/lib/minios-desktop/build-common.sh").exists())
        if (module / "rootcopy-postinstall").exists():
            shutil.copytree(module / "rootcopy-postinstall", target, dirs_exist_ok=True)
        return target

    def test_shared_build_functions_are_in_minioslib_not_rootcopy(self):
        result = subprocess.run(["bash", "-c", '. "$1"; declare -F minios_desktop_openbox_defaults; declare -F minios_desktop_defaults', "test", str(COMMON)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        for desktop in DESKTOPS:
            module = SCRIPTS / f"04-{desktop}-desktop"
            self.assertFalse((module / "build-common").exists())
            self.assertNotIn(". /build-common", (module / "install").read_text())
            for tree in (SCRIPTS / "03-gui-base/rootcopy-install", module / "rootcopy-install", module / "rootcopy-postinstall"):
                self.assertFalse((tree / "usr/lib/minios-desktop/build-common.sh").exists())
                self.assertFalse((tree / "build-common").exists())

    def test_native_merged_menu_directory_can_alias_shared_directory(self):
        for desktop in ("cinnamon",):
            with self.subTest(desktop=desktop), tempfile.TemporaryDirectory() as directory:
                target = self.build_fixture(directory, desktop, "standard", "trixie", merged_menu_alias=True)
                shared = target / "etc/xdg/menus/applications-merged/minios.menu"
                native = target / f"etc/xdg/menus/{desktop}-applications-merged/minios.menu"
                self.assertTrue(native.samefile(shared))
                self.assertEqual(ET.parse(native).find("Menu/Name").text, "MiniOS")

    def test_generated_configs_for_all_editions_and_init_systems(self):
        for desktop in DESKTOPS:
            for variant in VARIANTS:
                for distribution in ("trixie", "excalibur"):
                    with self.subTest(desktop=desktop, variant=variant, distribution=distribution), tempfile.TemporaryDirectory() as directory:
                        target = self.build_fixture(directory, desktop, variant, distribution)
                        config = target / "etc/skel/.config"
                        gtk = ini(config / "gtk-3.0/settings.ini")
                        self.assertEqual(gtk["Settings"]["gtk-font-name"], "Inter 9")
                        self.assertEqual(gtk["Settings"]["gtk-icon-theme-name"], "elementary-minios-dark")
                        self.assertEqual(gtk["Settings"]["gtk-theme-name"], "Greybird-MiniOS-dark" if variant == "ultra" else "Greybird-MiniOS")
                        ET.parse(config / "doublecmd/doublecmd.xml")
                        ET.parse(target / "etc/xdg/menus/applications-merged/minios.menu")
                        if desktop in ("gnome", "cinnamon"):
                            profile = (target / "etc/dconf/profile/user").read_text().splitlines()
                            self.assertEqual(profile, ["user-db:user", f"file-db:{target}/etc/dconf/db/minios"])
                        if desktop == "gnome":
                            settings = ini(target / "etc/dconf/db/minios.d/00-desktop")
                            background = settings["org/gnome/desktop/background"]["picture-uri"]
                            self.assertIn(f"minios6-{variant}.jpg", background)
                            self.assertEqual(settings["org/gnome/desktop/interface"]["enable-animations"], "false" if variant == "minimum" else "true")
                            keyboard = ini(target / "etc/dconf/db/minios.d/10-keyboard")
                            self.assertEqual(keyboard["org/gnome/desktop/input-sources"]["sources"], "[('xkb', 'us'), ('xkb', 'ru')]")
                            ET.parse(target / "usr/share/gnome-background-properties/minios.xml")
                            self.assertTrue((config / "systemd/user/localsearch-3.service").is_symlink())
                            if distribution == "excalibur":
                                session_defaults = ini(target / "etc/dconf/db/minios.d/20-non-systemd")
                                self.assertEqual(session_defaults["org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/lock"]["command"], "'light-locker-command -l'")
                        elif desktop == "lxqt":
                            ns = {"ob": "http://openbox.org/3.4/rc"}
                            rc = ET.parse(config / f"openbox/{desktop}-rc.xml")
                            self.assertEqual(rc.find("ob:theme/ob:name", ns).text, "Greybird-MiniOS-dark" if variant == "ultra" else "Greybird-MiniOS")
                            self.assertEqual(rc.find("ob:desktops/ob:number", ns).text, "1")
                            self.assertEqual(rc.find("ob:keyboard/ob:keybind[@key='C-A-t']/ob:action/ob:command", ns).text, "qterminal")
                            self.assertIsNotNone(rc.find("ob:mouse/ob:context", ns))
                            self.assertEqual((config / "minios/keyboard.conf").read_text().strip(), "MINIOS_XKB_LAYOUTS=us,ru")
                            appearance = ini(config / "lxqt/lxqt.conf")
                            self.assertEqual(appearance["General"]["icon_theme"], "elementary-minios-dark")
                            wallpaper = ini(config / "pcmanfm-qt/lxqt/settings.conf")["Desktop"]["Wallpaper"]
                            panel = ini(config / "lxqt/panel.conf")
                            self.assertEqual(panel["volume"]["audioEngine"], "PulseAudio")
                            self.assertEqual(panel["quicklaunch"]["apps\\2\\desktop"], "/usr/share/applications/qterminal.desktop")
                            self.assertIn(f"minios6-{variant}.jpg", wallpaper)
                            self.assertFalse((target / "etc/xdg/autostart/minios-light-locker.desktop").exists())
                            self.assertTrue((target / "etc/xdg/autostart/light-locker.desktop").exists())
                        else:
                            defaults = ini(target / "etc/dconf/db/minios.d/00-desktop")
                            native_menu = target / f"etc/xdg/menus/{desktop}-applications-merged/minios.menu"
                            self.assertEqual(ET.parse(native_menu).find("Menu/Name").text, "MiniOS")
                            interface = defaults[f"org/{desktop}/desktop/interface"]
                            self.assertEqual(interface["font-name"], "'Inter 9'")
                            background = defaults[f"org/{desktop}/desktop/background"]
                            self.assertIn(f"minios6-{variant}.jpg", background["picture-uri"])
                            keyboard = ini(target / "etc/dconf/db/minios.d/10-keyboard")
                            self.assertEqual(keyboard["org/cinnamon/desktop/input-sources"]["sources"], "[('xkb', 'us'), ('xkb', 'ru')]")
                            menu = json.loads((config / "cinnamon/spices/menu@cinnamon.org/0.json").read_text())
                            self.assertTrue(menu["menu-custom"]["value"])
                            self.assertTrue(menu["menu-icon"]["value"].endswith("/usr/share/pixmaps/MiniOS-white.svg"))
                            self.assertFalse(menu["show-recents"]["value"])
                            self.assertEqual(menu["untouched"]["value"], 42)
                            self.assertEqual(len(menu["__md5__"]), 32)
                            self.assertEqual(defaults["org/cinnamon"]["desktop-effects"], "false" if variant == "minimum" else "true")
                        if desktop != "gnome" or distribution == "excalibur":
                            lightdm = ini(target / "etc/lightdm/lightdm.conf.d/60-minios-desktop.conf")
                            self.assertEqual(lightdm["Seat:*"]["autologin-session"], f"minios-{desktop}")

    def selected_packages(self, desktop, variant, distribution):
        script = '''
source "$1/linux-live/condinapt"
load_filter_mapping "$1/linux-live/condinapt.map"
check_package() { return 0; }
CHECK_ONLY=false
SIMULATION_MODE=true
VERBOSITY_LEVEL=0
PACKAGES_TO_INSTALL=()
PACKAGES_TO_HOLD=()
MISSING_PACKAGES=()
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    process_package_conditions "$line" 0
done < "$1/linux-live/scripts/04-$DESKTOP_ENVIRONMENT-desktop/packages.list"
printf '%s\\n' "${PACKAGES_TO_INSTALL[@]}"
'''
        env = dict(os.environ, DESKTOP_ENVIRONMENT=desktop, PACKAGE_VARIANT=variant,
                   DISTRIBUTION=distribution, DISTRIBUTION_PROFILE="debian",
                   DISTRIBUTION_ARCH="amd64", INIT_SYSTEM="sysvinit" if distribution == "excalibur" else "systemd",
                   LOCALE="en_US", MULTILINGUAL="false", KEEP_LOCALES="false")
        result = subprocess.run(["bash", "-c", script, "test", str(ROOT)], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return set(result.stdout.splitlines())

    def test_package_filter_matrix(self):
        for desktop in DESKTOPS:
            for variant in VARIANTS:
                for distribution in ("trixie", "excalibur"):
                    with self.subTest(desktop=desktop, variant=variant, distribution=distribution):
                        packages = self.selected_packages(desktop, variant, distribution)
                        self.assertIn(f"minios6-wallpapers-{variant}", packages)
                        self.assertEqual("minios-installer" in packages, variant != "minimum")
                        self.assertIn("pipewire-pulse", packages)
                        self.assertNotIn("pulseaudio", packages)
                        self.assertIn("libpam-elogind" if distribution == "excalibur" else "libpam-systemd", packages)
                        self.assertFalse(packages & {"gnome", "gnome-core", "gnome-software", "cinnamon-core", "cinnamon-desktop-environment", "lxqt", "lxqt-core", "lubuntu-desktop"})
                        if desktop == "gnome":
                            self.assertIn("dconf-cli", packages)
                            self.assertEqual("gdm3" in packages, distribution != "excalibur")
                            self.assertEqual("lightdm" in packages, distribution == "excalibur")
                            self.assertEqual("light-locker" in packages, distribution == "excalibur")
                        elif desktop == "cinnamon":
                            self.assertIn("lightdm", packages)
                            self.assertIn("dconf-cli", packages)
                            self.assertIn("nemo", packages)
                            self.assertNotIn("gdm3", packages)
                        else:
                            self.assertIn("lightdm", packages)
                            self.assertNotIn("gdm3", packages)
                            self.assertNotIn("slim", packages)
                            self.assertNotIn("nodm", packages)
                            self.assertIn("qterminal", packages)

    def test_purge_rejects_removal_of_desktop_dependency(self):
        script = '''
source "$1"
pkg_is_installed() { return 0; }
apt-get() {
    if [ "$1" = -s ]; then
        printf 'Purg gnome-software [1.0]\\nRemv gnome-shell [1.0]\\n'
    else
        printf 'UNSAFE PURGE EXECUTED\\n'
    fi
}
minios_desktop_remove_optional gnome-software
'''
        result = subprocess.run(["bash", "-c", script, "test", str(COMMON)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing to remove desktop dependency: gnome-shell", result.stderr)
        self.assertNotIn("UNSAFE PURGE EXECUTED", result.stdout)

    def test_purge_accepts_only_requested_packages_with_arch_suffix(self):
        script = '''
source "$1"
pkg_is_installed() { return 0; }
apt-get() {
    if [ "$1" = -s ]; then
        printf 'Purg gnome-software:amd64 [1.0]\\n'
    else
        printf '%s\\n' "$*"
    fi
}
minios_desktop_remove_optional gnome-software
'''
        result = subprocess.run(["bash", "-c", script, "test", str(COMMON)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "-y purge gnome-software")

    def test_pipewire_repairs_partial_session_without_duplicate_core(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            commands = target / "bin"
            commands.mkdir()
            for daemon in ("pipewire", "pipewire-pulse", "wireplumber"):
                stub = commands / daemon
                stub.write_text(f"#!/bin/sh\nprintf '{daemon} started\\n'\n")
                stub.chmod(0o755)
            pgrep = commands / "pgrep"
            pgrep.write_text('#!/bin/sh\n[ "$4" = pipewire ]\n')
            pgrep.chmod(0o755)
            systemctl = commands / "systemctl"
            systemctl.write_text("#!/bin/sh\nexit 1\n")
            systemctl.chmod(0o755)
            with socket.socket(socket.AF_UNIX) as server:
                server.bind(str(target / "pipewire-0"))
                env = dict(os.environ, PATH=f"{commands}:{os.environ['PATH']}", XDG_RUNTIME_DIR=str(target))
                result = subprocess.run(["sh", str(SCRIPTS / "03-gui-base/rootcopy-install/usr/bin/minios-desktop-pipewire-start")], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                for daemon in ("pipewire-pulse", "wireplumber"):
                    log = target / f"{daemon}.log"
                    for _ in range(50):
                        if log.exists() and log.read_text():
                            break
                        time.sleep(0.01)
                    self.assertIn(f"{daemon} started", log.read_text())
                self.assertFalse((target / "pipewire.log").exists())

    def test_gnome_session_uses_builtin_only_without_systemd(self):
        for systemd in (True, False):
            with self.subTest(systemd=systemd), tempfile.TemporaryDirectory() as directory:
                target = Path(directory)
                if systemd:
                    (target / "systemd").mkdir()
                session = target / "session"
                session.write_text((SCRIPTS / "04-gnome-desktop/rootcopy-install/usr/bin/minios-gnome-session").read_text().replace('/run/systemd/system', str(target / "systemd")))
                gnome = target / "gnome-session"
                gnome.write_text('#!/bin/sh\nprintf "%s\\n" "$*"\n')
                gnome.chmod(0o755)
                dbus = target / "dbus-run-session"
                dbus.write_text('#!/bin/sh\nshift\nexec "$@"\n')
                dbus.chmod(0o755)
                env = dict(os.environ, PATH=f"{target}:{os.environ['PATH']}")
                env.pop("DBUS_SESSION_BUS_ADDRESS", None)
                result = subprocess.run(["sh", str(session)], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), "" if systemd else "--builtin")

    def test_desktop_wrappers_keep_session_environment_and_arguments(self):
        for desktop, desktop_name, binary, prefix, platform in (
                ("cinnamon", "X-Cinnamon", "cinnamon-session", "cinnamon-", "gtk3"),
                ("lxqt", "LXQt", "startlxqt", "lxqt-", "lxqt")):
            for existing_bus in (False, True):
                with self.subTest(desktop=desktop, existing_bus=existing_bus), tempfile.TemporaryDirectory() as directory:
                    target = Path(directory)
                    session = target / binary
                    session.write_text('#!/bin/sh\nprintf "%s\\n" "$XDG_CURRENT_DESKTOP" "${XDG_MENU_PREFIX:-}" "$QT_QPA_PLATFORMTHEME" "$@"\n')
                    session.chmod(0o755)
                    dbus = target / "dbus-run-session"
                    dbus.write_text('#!/bin/sh\nprintf "new-bus\\n"\nshift\nexec "$@"\n')
                    dbus.chmod(0o755)
                    env = dict(os.environ, PATH=f"{target}:{os.environ['PATH']}")
                    env.pop("DBUS_SESSION_BUS_ADDRESS", None)
                    env.pop("XDG_MENU_PREFIX", None)
                    if existing_bus:
                        env["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=/test/session-bus"
                    wrapper = SCRIPTS / f"04-{desktop}-desktop/rootcopy-install/usr/bin/minios-{desktop}-session"
                    result = subprocess.run(["sh", str(wrapper), "--test-option", "two words"], env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    expected = [desktop_name, prefix, platform, "--test-option", "two words"]
                    if not existing_bus:
                        expected.insert(0, "new-bus")
                    self.assertEqual(result.stdout.splitlines(), expected)

    def test_dconf_desktop_databases_compile(self):
        compiler = os.environ.get("MINIOS_DCONF_BINARY") or shutil.which("dconf")
        if not compiler:
            self.skipTest("dconf-cli is not installed; set MINIOS_DCONF_BINARY to an extracted compiler")
        for desktop in ("gnome", "cinnamon"):
            for variant in VARIANTS:
                with self.subTest(desktop=desktop, variant=variant), tempfile.TemporaryDirectory() as directory:
                    target = self.build_fixture(directory, desktop, variant, "trixie")
                    result = subprocess.run([compiler, "compile", str(target / "minios.db"), str(target / "etc/dconf/db/minios.d")], capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertGreater((target / "minios.db").stat().st_size, 0)

    def test_dconf_factory_defaults_allow_early_writes_without_a_system_bus(self):
        import signal

        compiler = os.environ.get("MINIOS_DCONF_BINARY") or shutil.which("dconf")
        if not compiler or not shutil.which("dbus-run-session") or not shutil.which("gsettings"):
            self.skipTest("dconf compiler and GSettings/session bus tools are required")
        if not Path("/usr/libexec/dconf-service").exists():
            self.skipTest("dconf-service is required for real backend verification")
        with tempfile.TemporaryDirectory(prefix="minios-dconf-") as directory:
            target = self.build_fixture(directory, "gnome", "standard", "trixie")
            subprocess.run([compiler, "compile", str(target / "etc/dconf/db/minios"), str(target / "etc/dconf/db/minios.d")], check=True, capture_output=True)
            home = target / "test-user"
            runtime = home / "runtime"
            runtime.mkdir(parents=True, mode=0o700)
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
                       XDG_RUNTIME_DIR=str(runtime), DCONF_PROFILE=str(target / "etc/dconf/profile/user"),
                       GSETTINGS_BACKEND="dconf", DBUS_SYSTEM_BUS_ADDRESS=f"unix:path={target}/bus")
            env.pop("DBUS_SESSION_BUS_ADDRESS", None)

            def gsettings(*args):
                process = subprocess.Popen(["dbus-run-session", "--", "gsettings", *args], env=env,
                                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                           start_new_session=True)
                try:
                    output, errors = process.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.communicate()
                    self.fail("GSettings waited for the unavailable system bus")
                self.assertEqual(process.returncode, 0, errors)
                return output.strip()

            # Like dbus.socket during early boot: connect succeeds but there is
            # no system daemon to complete authentication or answer requests.
            with socket.socket(socket.AF_UNIX) as blocked_system_bus:
                blocked_system_bus.bind(str(target / "bus"))
                blocked_system_bus.listen(10)
                gsettings("set", "org.gnome.desktop.screensaver", "lock-enabled", "false")
                self.assertEqual(gsettings("get", "org.gnome.desktop.screensaver", "lock-enabled"), "false")
                self.assertEqual(gsettings("get", "org.gnome.desktop.interface", "gtk-theme"), "'Greybird-MiniOS'")
                gsettings("set", "org.gnome.desktop.interface", "gtk-theme", "UserTheme")
                self.assertEqual(gsettings("get", "org.gnome.desktop.interface", "gtk-theme"), "'UserTheme'")
                gsettings("reset", "org.gnome.desktop.interface", "gtk-theme")
                self.assertEqual(gsettings("get", "org.gnome.desktop.interface", "gtk-theme"), "'Greybird-MiniOS'")
                blocked_system_bus.setblocking(False)
                with self.assertRaises(BlockingIOError):
                    blocked_system_bus.accept()

    def test_modern_desktop_chains_share_edition_apps(self):
        for desktop in DESKTOPS:
            environment = ROOT / "linux-live/environments" / desktop
            self.assertEqual((environment / "05-apps").resolve(), SCRIPTS / "05-apps")
            self.assertEqual((environment / f"04-{desktop}-desktop").resolve(), SCRIPTS / f"04-{desktop}-desktop")
            self.assertFalse((environment / "05-lxqt-apps").exists())

    def test_x11_keyboard_helper_respects_editable_user_layout(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            config = target / "minios/keyboard.conf"
            config.parent.mkdir()
            config.write_text("MINIOS_XKB_LAYOUTS=us,de\n")
            command = target / "setxkbmap"
            command.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            command.chmod(0o755)
            env = dict(os.environ, XDG_CONFIG_HOME=str(target), PATH=f"{target}:{os.environ['PATH']}")
            helper = SCRIPTS / "03-gui-base/rootcopy-install/usr/bin/minios-desktop-keyboard"
            result = subprocess.run(["sh", str(helper)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), ["-layout", "us,de", "-option", "", "-option", "grp:alt_shift_toggle"])


if __name__ == "__main__":
    unittest.main()

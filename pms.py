# // PMS - PackMySeal
# // Package / Module manager for TuffSeal

from pathlib import Path
import sys
import os
import json
import requests
import zipfile
import tempfile
import platform
from typing import Dict

PMS_SERVER = "https://packmyseal.pythonanywhere.com"

HELP_MESSAGE = """\
Usage: pms [command] [arguments]...

Commands:
    init <project_name>                 Initialize a new TuffSeal project
    install <module>[@version] [dir]    Install module (latest version if not specified)
    upload <name> <version> <zipfile>   Upload module to PMS repository
    list <module>                       Show available versions of a module
    remove <module> [dir]               Remove module from project
    register <username> <password>      Create new PMS account
    login <username> <password>         Log in and save credentials
    logout                              Log out (clear saved credentials)
    whoami                              Show currently logged in user

NOTE: To use some PMS functions, you need a PMS account.
Use 'pms register <username> <password>' to create a PMS account.
If you already have an account, use 'pms login <username> <password>' to log in.
"""

def get_auth_path() -> Path:
    system = platform.system()
    if system == "Linux":
        base = Path.home() / ".packmyseal"
    elif system == "Darwin":
        base = Path.home() / "Library" / "Application Support" / "PackMySeal"
    else:
        base = Path(os.getenv("APPDATA", "")) / "PackMySeal"

    base.mkdir(parents=True, exist_ok=True)
    return base / "pms_auth.json"


def load_auth() -> Dict[str, str]:
    path = get_auth_path()
    if not path.exists():
        print("This command requires authentication.")
        print("Run 'pms register <username> <password>' or 'pms login <username> <password>' first.")
        sys.exit(1)
    
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Failed to read auth file: {e}")
        sys.exit(1)


def save_auth(username: str, token: str) -> None:
    data = {"username": username, "token": token}
    try:
        with open(get_auth_path(), "w", encoding="utf-8") as f:
            json.dump(data, f)
    except Exception as e:
        print(f"Failed to save auth data: {e}")
        sys.exit(1)


def clear_auth() -> None:
    try:
        get_auth_path().unlink(missing_ok=True)
    except Exception:
        pass


def ask_confirm(message: str) -> bool:
    answer = input(f"{message} (y/N): ").strip().lower()
    return answer in ('y', 'yes')


def load_project_metadata(project_dir: str = ".") -> dict:
    path = Path(project_dir) / "pms_project.json"
    if not path.is_file():
        print("Project not initialized. Run 'pms init <name>' first.")
        sys.exit(1)
    
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Failed to read project metadata: {e}")
        sys.exit(1)


def save_project_metadata(metadata: dict, project_dir: str = ".") -> None:
    path = Path(project_dir) / "pms_project.json"
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(metadata, f, indent=2)
    except Exception as e:
        print(f"Failed to save project metadata: {e}")
        sys.exit(1)


def cmd_init() -> None:
    if len(sys.argv) < 3:
        print("Missing project name!")
        print("Usage: pms init <project_name>")
        sys.exit(1)

    name = sys.argv[2]
    project_path = Path(name)

    try:
        project_path.mkdir(exist_ok=True)
        (project_path / "Modules").mkdir(exist_ok=True)

        metadata = {
            "name": project_path.resolve().name,
            "modules": {}
        }
        save_project_metadata(metadata, str(project_path))

        main_file = project_path / "main.tfs"
        main_file.write_text("""\
// main.tfs
fn main() {
    print("Hello, world!");
}
main();
""", encoding="utf-8")

        print(f"New project initialized: {name}")
    except Exception as e:
        print(f"Failed to initialize project: {e}")
        sys.exit(1)


def cmd_install() -> None:
    if len(sys.argv) < 3:
        print("Missing module name!")
        print("Usage: pms install <module>[@version] [project_dir]")
        sys.exit(1)

    module_str = sys.argv[2]
    project_dir = sys.argv[3] if len(sys.argv) > 3 else "."

    if "@" in module_str:
        module_name, version = module_str.split("@", 1)
    else:
        module_name = module_str
        version = "latest"

    if not ask_confirm(f"Install '{module_name}@{version}'?"):
        sys.exit(0)

    print(f"Downloading {module_name}@{version}...")

    params = {} if version == "latest" else {"version": version}
    url = f"{PMS_SERVER}/modules/{module_name}"

    try:
        with requests.get(url, params=params, stream=True, timeout=30) as r:
            r.raise_for_status()
            with tempfile.NamedTemporaryFile(delete=False, suffix=".zip") as tmp:
                for chunk in r.iter_content(16384):
                    tmp.write(chunk)
                tmp_path = tmp.name

        target_dir = Path(project_dir) / "Modules" / module_name
        target_dir.mkdir(parents=True, exist_ok=True)

        with zipfile.ZipFile(tmp_path) as zf:
            zf.extractall(target_dir)

        os.unlink(tmp_path)

        metadata = load_project_metadata(project_dir)
        metadata.setdefault("modules", {})[module_name] = version
        save_project_metadata(metadata, project_dir)

        print(f"Successfully installed {module_name}@{version}")

    except requests.RequestException as e:
        print(f"Download failed: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Installation failed: {e}")
        sys.exit(1)


def cmd_remove() -> None:
    if len(sys.argv) < 3:
        print("Missing module name!")
        sys.exit(1)

    module_name = sys.argv[2]
    project_dir = sys.argv[3] if len(sys.argv) > 3 else "."

    module_path = Path(project_dir) / "Modules" / module_name

    if not module_path.exists():
        print(f"Module '{module_name}' not found in project.")
        sys.exit(1)

    if not ask_confirm(f"Remove module '{module_name}' from project?"):
        sys.exit(0)

    try:
        import shutil
        shutil.rmtree(module_path)

        metadata = load_project_metadata(project_dir)
        metadata["modules"].pop(module_name, None)
        save_project_metadata(metadata, project_dir)

        print(f"Module '{module_name}' removed.")
    except Exception as e:
        print(f"Failed to remove module: {e}")
        sys.exit(1)


def cmd_list_versions() -> None:
    if len(sys.argv) < 3:
        print("Missing module name!")
        sys.exit(1)

    module_name = sys.argv[2]
    url = f"{PMS_SERVER}/modules/{module_name}/versions"

    try:
        r = requests.get(url, timeout=15)
        r.raise_for_status()
        data = r.json()
        print(f"Available versions for '{module_name}':")
        for v in data.get("versions", []):
            print(f"  • {v}")
    except Exception as e:
        print(f"Failed to fetch versions: {e}")


def cmd_register() -> None:
    if len(sys.argv) != 4:
        print("Usage: pms register <username> <password>")
        sys.exit(1)

    username, password = sys.argv[2], sys.argv[3]

    try:
        r = requests.post(
            f"{PMS_SERVER}/register",
            json={"username": username, "password": password},
            timeout=15
        )
        r.raise_for_status()
        print("Account created successfully!")
        print("Now log in with:  pms login", username, "<password>")
    except Exception as e:
        print(f"Registration failed: {e}")


def cmd_login() -> None:
    if len(sys.argv) != 4:
        print("Usage: pms login <username> <password>")
        sys.exit(1)

    username, password = sys.argv[2], sys.argv[3]

    try:
        r = requests.post(
            f"{PMS_SERVER}/login",
            json={"username": username, "password": password},
            timeout=15
        )
        r.raise_for_status()
        token = r.json().get("token")
        if not token:
            print("Login successful but no token received.")
            sys.exit(1)

        save_auth(username, token)
        print("Login successful. Credentials saved.")
    except Exception as e:
        print(f"Login failed: {e}")


def cmd_whoami() -> None:
    try:
        auth = load_auth()
        r = requests.get(
            f"{PMS_SERVER}/whoami",
            headers={"Authorization": f"Bearer {auth['token']}"},
            timeout=10
        )
        r.raise_for_status()
        print(r.json().get("username", "unknown"))
    except Exception as e:
        print(f"Failed to get current user: {e}")


def cmd_upload() -> None:
    if len(sys.argv) != 5:
        print("Usage: pms upload <module_name> <version> <zip_file>")
        sys.exit(1)

    module_name = sys.argv[2]
    version = sys.argv[3]
    zip_path = sys.argv[4]

    if not Path(zip_path).is_file():
        print(f"File not found: {zip_path}")
        sys.exit(1)

    try:
        auth = load_auth()
        filename = f"{module_name}@{version}.zip"

        if not ask_confirm(f"Upload {filename}?"):
            sys.exit(0)

        with open(zip_path, "rb") as f:
            files = {"file": (filename, f)}
            headers = {"Authorization": f"Bearer {auth['token']}"}

            r = requests.post(
                f"{PMS_SERVER}/modules/upload",
                headers=headers,
                files=files,
                timeout=60
            )
            r.raise_for_status()

        print(f"Module {filename} uploaded successfully!")
    except Exception as e:
        print(f"Upload failed: {e}")
        sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print("Too few arguments. Use 'pms help' for usage.")
        sys.exit(1)

    cmd = sys.argv[1].lower()

    commands = {
        "init":     cmd_init,
        "install":  cmd_install,
        "remove":   cmd_remove,
        "list":     cmd_list_versions,
        "register": cmd_register,
        "login":    cmd_login,
        "logout":   lambda: (ask_confirm("Log out?") and clear_auth() and print("Logged out.")),
        "whoami":   cmd_whoami,
        "upload":   cmd_upload,
        "help":     lambda: print(HELP_MESSAGE)
    }

    if cmd not in commands:
        print(f"Unknown command: {cmd}")
        print("Use 'pms help' to see available commands.")
        sys.exit(1)

    try:
        commands[cmd]()
    except KeyboardInterrupt:
        print("\nCancelled.")
        sys.exit(1)


if __name__ == "__main__":
    main()
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
    updatemodules [dir]                 Check for module updates
    deletefrompms <module>[@version]    Permanently deletes a module from PMS servers.
    register <username> <password>      Create new PMS account
    login <username> <password>         Log in and save credentials
    logout                              Log out (clear saved credentials)
    whoami                              Show currently logged in user

NOTE: To use some PMS functions, you need a PMS account.
Use 'pms register <username> <password>' to create a PMS account.
If you already have an account, use 'pms login <username> <password>' to log in.

WARNING: To remove modules from your project use 'remove', not 'deletefrompms'!
'deletefrompms' will permanently remove the module from the PMS server,
while 'remove' will only remove it from your project!
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


def save_auth(username: str, token: str, refresh_token: str) -> None:
    data = {"username": username, "token": token, "refresh_token": refresh_token}
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


def is_access_token_alive() -> bool:
    url = f"{PMS_SERVER}/check"
    auth = load_auth()
    try:
        r = requests.get(
            url=url,
            headers={
                "Authorization": f"Bearer {auth['token']}"
            }
        )
        r.raise_for_status()
        data = r.json()
        return data['alive']
    except Exception as e:
        return False

def ask_confirm(message: str) -> bool:
    answer = input(f"{message} (y/N): ").strip().lower()
    r = answer.lower() in ('y', 'yes')
    if r != True:
        print("Cancelled.")
        sys.exit(1)

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

def get_latest_version(package_name: str) -> [str]:
    url = f"{PMS_SERVER}/modules/{package_name}/versions/latest"

    try:
        r = requests.get(url, timeout=15)
        r.raise_for_status()
        return r.text
    except Exception as e:
        return e
    

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
        version = get_latest_version(module_name)

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
        refresh = r.json().get("refresh_token")
        if not token or not refresh:
            print("Login successful but no token received.")
            sys.exit(1)

        save_auth(username, token, refresh)
        print("Login successful. Credentials saved.")
    except Exception as e:
        print(f"Login failed: {e}")


def cmd_whoami() -> None:
    refresh_auth_token()
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


def refresh_auth_token():
    if is_access_token_alive():
        return
    
    print("Expired access token detected! Refreshing...")

    auth = load_auth()
    refresh = auth.get("refresh_token")

    if not refresh:
        print("Refresh token not found in auth file! Please, log into your account again.")
        sys.exit(1)

    try:
        r = requests.get(
            url=f"{PMS_SERVER}/refresh",
            headers={
                "Authorization": f"Bearer {refresh}"
            }
        )
        r.raise_for_status()

        data = r.json()
        new_access_token = data.get("token")
        if not new_access_token:
            print("Token refresh succeeded but no token was returned!")
            sys.exit(1)

        save_auth(auth.get("username"), new_access_token, auth.get("refresh_token"))
        print("Refresh successful! Resuming.")
    except Exception as e:
        print(f"Error while refreshing token: {e}")
        sys.exit(1)

def cmd_upload() -> None:
    if len(sys.argv) != 5:
        print("Usage: pms upload <module_name> <version> <zip_file>")
        sys.exit(1)

    module_name = sys.argv[2]
    version = sys.argv[3]
    zip_path = sys.argv[4]

    refresh_auth_token()

    auth = load_auth()

    if not Path(zip_path).is_file():
        print(f"File not found: {zip_path}")
        sys.exit(1)

    try:
        filename = f"{module_name}@{version}.zip"

        ask_confirm(f"Upload {filename}?")

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


def cmd_update_modules():
    project_name = "."

    if len(sys.argv) >= 3:
        project_name = sys.argv[2]

    print(f"Checking for updates in '{project_name}'...")

    modules_path = os.path.join(project_name, "Modules")
    os.makedirs(modules_path, exist_ok=True)
    metadata = load_project_metadata(project_name)

    if not "modules" in metadata:
        metadata['modules'] = {}

    m_modules = metadata['modules']

    TO_UPDATE = []
    for module in m_modules:
        latest = ""
        try:
            latest = get_latest_version()
        except Exception as e:
            print(f"Error while getting latest version: {e}")
            print("Proceeding to next module...")
            continue

        if module == latest:
            print(f"Module {module} is on the latest version! Proceeding to next module..")
            continue
        
        TO_UPDATE.append(module)

    for to_update_m in TO_UPDATE:
        latest_ver = get_latest_version(to_update_m)
        url = f"{PMS_SERVER}/modules/{to_update_m}"
        module_path = os.path.join(project_name, "Modules", to_update_m)

        params = {}

        try:
            os.removedirs()
        except Exception as e:
            print(f"Failed to remove old module for: {e}, proceeding to the next module..")
            continue

        try:
            with requests.get(url, params=params, stream=True, timeout=30) as r:
                r.raise_for_status()
                with tempfile.NamedTemporaryFile(delete=False, suffix=".zip") as tmp:
                    for chunk in r.iter_content(16384):
                        tmp.write(chunk)
                    tmp_path = tmp.name

            target_dir = Path(project_name) / "Modules" / to_update_m
            target_dir.mkdir(parents=True, exist_ok=True)

            with zipfile.ZipFile(tmp_path) as zf:
                zf.extractall(target_dir)

            os.unlink(tmp_path)

            metadata = load_project_metadata(project_name)
            metadata.setdefault("modules", {})[to_update_m] = latest_ver
            save_project_metadata(metadata, project_name)

            print(f"Successfully installed {to_update_m}@{latest_ver}")

        except requests.RequestException as e:
            print(f"Download failed for module {to_update_m}: {e}")
            sys.exit(1)
        except Exception as e:
            print(f"Installation failed for module {to_update_m}: {e}")
            sys.exit(1)


def cmd_delete_from_pls():
    if len(sys.argv) < 2:
        print("Usage: pms deletefrompms <module>[@version]\nOR: pms deletefrompms <module>")

    refresh_auth_token()

    fullname = sys.argv[2]
    vername = None
    if "@" in fullname:
        fullname, vername = fullname.split("@", 2)

    if vername:
        ask_confirm(f"Are you sure you want to delete version '{vername}' from the module '{fullname}'?")
    else:
        ask_confirm(f"Are you sure you want to delete the ENTIRE MODULE '{fullname}'?")
        ask_confirm(f"Are you REALLY sure you want to delete the module '{fullname}'?")

    print("Starting deletion!")

    json = {}
    if vername:
        json = {"version": vername}

    auth = load_auth()

    try:
        r = requests.post(
            url=f"{PMS_SERVER}/modules/{fullname}/delete",
            json=json,
            headers={
                "Authorization": f"Bearer {auth.get("token")}"
            }
        )
        r.raise_for_status()

        data = r.json()
        print(data.get("msg"))
    except Exception as e:
        print(f"Error deleting: {e}")
        sys.exit(1)

    print("Finished deleting.")

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
        "updatemodules": cmd_update_modules,
        "deletefrompms": cmd_delete_from_pls,
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
:: BUILD_PMS.bat -> building packmyseal pms.exe from pms.py

pip install pyinstaller
pip install requests

:: build
pyinstaller --noconfirm --onefile --console --hidden-import "requests"  "pms.py"

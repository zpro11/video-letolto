import sys
from PyQt5.QtWidgets import QApplication, QWidget, QVBoxLayout, QLabel, QLineEdit, QPushButton, QComboBox, QFileDialog, QMessageBox, QProgressBar
from PyQt5.QtGui import QIcon
import yt_dlp
import threading

class Letolto(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle('YouTube Letöltő')
        self.setWindowIcon(QIcon())
        self.setGeometry(100, 100, 400, 250)
        self.felulet()

    def felulet(self):
        elrendezes = QVBoxLayout()
        self.cimke_url = QLabel('Videó URL:')
        self.mezo_url = QLineEdit()
        self.cimke_mod = QLabel('Letöltési mód:')
        self.mod_valaszto = QComboBox()
        self.mod_valaszto.addItems(['Videó + Hang', 'Csak Hang (mp3)', 'Csak Videó'])
        self.cimke_felbontas = QLabel('Felbontás:')
        self.felbontas_valaszto = QComboBox()
        self.felbontas_valaszto.addItem('Elérhető felbontásokhoz URL kell.')
        self.felbontas_valaszto.setEnabled(False)
        self.mezo_url.textChanged.connect(self.felbontasok)
        self.gomb_kimenet = QPushButton('Kimeneti mappa kiválasztása')
        self.gomb_kimenet.clicked.connect(self.kimenet)
        self.kimeneti_mappa = ''
        self.gomb_letoltes = QPushButton('Letöltés
        (Előbb válaszd ki a kimeneti mapát)')
        self.gomb_letoltes.clicked.connect(self.letoltes)
        self.cimke_allapot = QLabel('Letöltés állapota:')
        self.sav = QProgressBar()
        self.sav.setValue(0)
        self.cimke_statusz = QLabel('')
        elrendezes.addWidget(self.cimke_url)
        elrendezes.addWidget(self.mezo_url)
        elrendezes.addWidget(self.cimke_mod)
        elrendezes.addWidget(self.mod_valaszto)
        elrendezes.addWidget(self.cimke_felbontas)
        elrendezes.addWidget(self.felbontas_valaszto)
        elrendezes.addWidget(self.gomb_kimenet)
        elrendezes.addWidget(self.gomb_letoltes)
        elrendezes.addWidget(self.cimke_allapot)
        elrendezes.addWidget(self.sav)
        elrendezes.addWidget(self.cimke_statusz)
        self.setLayout(elrendezes)
    def felbontasok(self):
        url = self.mezo_url.text().strip()
        if not url:
            self.felbontas_valaszto.clear()
            self.felbontas_valaszto.addItem('Elérhető felbontásokhoz URL-t adj meg!')
            self.felbontas_valaszto.setEnabled(False)
            return
        self.felbontas_valaszto.clear()
        self.felbontas_valaszto.addItem('Felbontások lekérése...')
        self.felbontas_valaszto.setEnabled(False)
        def formatok():
            try:
                ydl_opts = {'quiet': True, 'skip_download': True}
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    info = ydl.extract_info(url, download=False)
                formatok_lista = info.get('formats', [])
                felbontasok = []
                for f in formatok_lista:
                    if f.get('vcodec') != 'none':
                        res = f.get('format_note') or (str(f.get('height')) + 'p' if f.get('height') else None)
                        if res and res not in felbontasok:
                            felbontasok.append(res)
                self.felbontas_valaszto.clear()
                if felbontasok:
                    self.felbontas_valaszto.addItems(felbontasok)
                    self.felbontas_valaszto.setEnabled(True)
                else:
                    self.felbontas_valaszto.addItem('Nem található felbontás')
                    self.felbontas_valaszto.setEnabled(False)
            except Exception:
                self.felbontas_valaszto.clear()
                self.felbontas_valaszto.addItem('Hibás vagy nem támogatott URL')
                self.felbontas_valaszto.setEnabled(False)
        threading.Thread(target=formatok, daemon=True).start()

    def kimenet(self):
        mappa = QFileDialog.getExistingDirectory(self, 'Kimeneti mappa kiválasztása')
        if mappa:
            self.kimeneti_mappa = mappa

    def letoltes(self):
        url = self.mezo_url.text().strip()
        if not url:
            QMessageBox.warning(self, 'Hiba', 'Add meg a YouTube videó URL-jét!')
            return
        if not self.kimeneti_mappa:
            QMessageBox.warning(self, 'Hiba', 'Válassz kimeneti mappát!')
            return
        mod = self.mod_valaszto.currentText()
        felbontas = self.felbontas_valaszto.currentText() if self.felbontas_valaszto.isEnabled() else None
        self.sav.setValue(0)
        self.cimke_statusz.setText('Letöltés indítása...')
        threading.Thread(target=self.folyamat, args=(url, mod, felbontas), daemon=True).start()

    def folyamat(self, url, mod, felbontas):
        def horog(d):
            if d.get('status') == 'downloading':
                szazalek = d.get('_percent_str', '0.0%').replace('%','').strip()
                try:
                    szazalek_ertek = float(szazalek)
                except:
                    szazalek_ertek = 0
                self.sav.setValue(int(szazalek_ertek))
                sebesseg = d.get('speed')
                ido = d.get('eta')
                sebesseg_szoveg = f'{sebesseg/1024:.2f} KB/s' if sebesseg else ''
                ido_szoveg = f'{ido} s' if ido else ''
                self.cimke_statusz.setText(f'Sebesség: {sebesseg_szoveg} | Hátralévő idő: {ido_szoveg}')
            elif d.get('status') == 'finished':
                self.sav.setValue(100)
                self.cimke_statusz.setText('Letöltés kész!')
        beallitasok = {
            'outtmpl': f'{self.kimeneti_mappa}/%(title)s.%(ext)s',
            'progress_hooks': [horog],
        }
        if mod == 'Videó + Hang':
            if felbontas and felbontas.endswith('p') and felbontas[:-1].isdigit():
                beallitasok['format'] = f'bestvideo[height={felbontas[:-1]}]+bestaudio/best'
            else:
                beallitasok['format'] = 'bestvideo+bestaudio/best'
        elif mod == 'Csak Hang (mp3)':
            beallitasok['format'] = 'bestaudio/best'
            beallitasok['postprocessors'] = [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '192',
            }]
        elif mod == 'Csak Videó':
            if felbontas and felbontas.endswith('p') and felbontas[:-1].isdigit():
                beallitasok['format'] = f'bestvideo[height={felbontas[:-1]}]'
            else:
                beallitasok['format'] = 'bestvideo'
        try:
            with yt_dlp.YoutubeDL(beallitasok) as ydl:
                ydl.download([url])
            QMessageBox.information(self, 'Sikeres letöltés', 'A letöltés befejeződött!')
        except Exception as e:
            QMessageBox.critical(self, 'Hiba', f'Hiba történt: {str(e)}')

def fo():
    app = QApplication(sys.argv)
    ablak = Letolto()
    ablak.show()
    sys.exit(app.exec_())

if __name__ == '__main__':
    fo()
